 --[[
 =head1 NAME
 
 jive.visImage - visualiser support
 
 =head1 DESCRIPTION
 
 Implements visualiser support 
  - menu selection support
  - resize for multiple resoultions
  - image caching
  - ....
 
 (c) Blaise Dias, 2023

 =cut
 --]]

--
-- lua package imports
local math	= require("math")
local table	= require("table")
local lfs	= require("lfs")
local os	= require("os")

local ipairs, pairs, pcall	= ipairs, pairs, pcall
local coroutine, package	= coroutine, package
local type	= type

-- jive package imports
local string		= require("jive.utils.string")
local Surface		= require("jive.ui.Surface")
local vis			= require("jive.vis")
local debug		 	= require("jive.utils.debug")
local log			= require("jive.utils.log").logger("jivelite.vis")
local System		= require("jive.System")

module(...)

SPT_DEFAULT = "default"
SPT_BACKLIT = "backlit"
SPT_IMAGE = "image"
SPT_COLOUR = "colour"

local vuImages = {}
local spectrumList = {}
local npvumeters = {}
local npspectrums = {}
local vuSeq = {}
local spSeq = {}
local visSettings = {}

-- set to true to create all resized visualiser images at startup
-- on resource constrained platforms like piCorePlayer jivelite terminate.
local resizeAll = false
-- resize all selected images at startup
-- on resource constrained platforms like piCorePlayer jivelite terminate.
local resizeAtStartUp = false
-- commit cached images to disk
local saveResizedImages = true
local saveAsPng = true
local PLATFORM = ""

-- on desktop OSes userPath is persistent
local workSpace = System.getUserDir()
local resizedCachePath = workSpace .. "/cache/resized"

function _parseImagePath(imgpath)
	local parts = string.split("%.", imgpath)
	local ix = #parts
	if parts[ix] == 'png' or parts[ix] == 'jpg' or parts[ix] == 'bmp' then
-- FIXME return array of size 2 always
		return parts
	end
	return nil
end

function boolOsEnv(envName, defaultValue)
	local tmp = os.getenv(envName)
	log:info("boolOsEnv:", envName, " defaultValue:", defaultValue, " got:", tmp)
	if tmp ~= nil then
		if defaultValue then
			if tmp == "0" or tmp == "false" or tmp ~= "False" then
				log:info("boolOsEnv: -> false")
				return false
			end
		else
			if tmp == "1" or tmp == "true" or tmp ~= "True" then
				log:info("boolOsEnv: -> true")
				return true
			end
		end
	end
	log:info("boolOsEnv: returning defaultValue: ", defaultValue)
	return defaultValue
end

local function ShuffleInPlace(t)
    if visSettings.randomSequence == true then
		for i = #t, 2, -1 do
			local j = math.random(i)
			t[i], t[j] = t[j], t[i]
		end
    end
end

-------------------------------------------------------- 
--- platform
-------------------------------------------------------- 
-- at the moment the only distinction is pcp or desktop
function platformDetect()
	if PLATFORM ~= "" then
		return PLATFORM
	end
	PLATFORM = "desktop"
	local mode
	pcp_version_file = "/usr/local/etc/pcp/pcpversion.cfg"
	mode = lfs.attributes(pcp_version_file, "mode")
	log:info("mode ", pcp_version_file, " " , mode)
	if mode == "file" then
		PLATFORM = "piCorePlayer"
		saveResizedImages = boolOsEnv("JL_SAVE_RESIZED_IMAGES", false)
		-- save as png is the exception - it must be explicitly disabled
		saveAsPng = boolOsEnv("JL_SAVE_AS_PNG", false)
	end
	resizeAll = boolOsEnv("JL_RESIZE_ALL", false)
	resizeAtStartUp = boolOsEnv("JL_RESIZE_AT_STARTUP", false)
	-- to support saving resized visualiser images
	-- in locations other then the home directory
	-- defining a path to a workspace is supported
	local tmp = os.getenv("JL_WORKSPACE") or nil
	if tmp ~= nil and string.len(tmp) ~= 0 then
		workSpace = tmp
		resizedCachePath = workSpace .. "/cache/resized"
		os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/spectrum/gradient")
		os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/spectrum/backlit")
		os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters/analogue")
		os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters/vfd")
	end
	os.execute("mkdir -p " .. resizedCachePath)
	log:info("PLATFORM:", PLATFORM, " workSpace:" , workSpace, " resizedCachePath:", resizedCachePath)
	log:info("resizeAll:", resizeAll, " resizeAtStartUp:" , resizeAtStartUp)
	log:info("saveResizedImages:", saveResizedImages, " saveAsPng:" , saveAsPng)
	return PLATFORM
end

-------------------------------------------------------- 
--- in memory image cache(s) 
-------------------------------------------------------- 

-- FIXME: vfdCache should go through imCache
vfdCache = {}
local imCache = {}

function imCachePut(key, img)
	log:info("imCache <- ", key,  " ", img)
	imCache[key] = img
end

function imCacheGet(key)
	local img = imCache[key]
	if img ~= nil then
		log:info("imCache -> ", key,  " ", img)
	else
		log:info("imCache X ", key)
	end
	return img
end

function imCacheClear()
	log:info("imCacheClear")
	vfdCache = {}
	for k,v in pairs(imCache) do
		log:info("releasing ", k)
		v:release()
	end
	imCache={}
end

function loadImage(path)
	img = imCacheGet(path)
	if img == nil  then
		img = Surface:loadImage(path)
		imCachePut(path,img)
	end
	return img
end

function saveImage(img, path, asPng)
	imCachePut(path, img)
	if saveResizedImages then
		if saveAsPng and asPng then
			img:savePNG(path)
		else
			img:saveBMP(path)
		end
	end
end

-------------------------------------------------------- 
--- disk image cache 
-------------------------------------------------------- 

local diskImageCache = {}
function getImageName(imgPath)
	local fullpath = string.split("/", imgPath)
	local name = fullpath[#fullpath]
	local parts = string.split("%.", name)
	return parts[1]
end

function pathIter(rpath)
	local hist = {}
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		if hist[dir] == nil then
			hist[dir] = true
			if dir ~= "./" then
				dir = dir .. rpath
				local mode = lfs.attributes(dir, "mode")
				if mode == "directory" then
					coroutine.yield(dir)
				end
			end
		end
	end
end

function findPaths(rpath)
	local co = coroutine.create(function() pathIter(rpath) end)
	return function()
		local code, res = coroutine.resume(co)
		return res
	end
end

function cachedPath(name, suffix)
	-- we don't know/care whether it is a bmp, png or jpeg 
	-- loading the file just works 
	local file = resizedCachePath .. "/" .. name .. "." .. suffix
	return file
end

function cacheClear(tbl)
	log:debug("cacheClear ")
	for k,v in pairs(diskImageCache) do
		log:debug("cacheClear ", k)
		diskImageCache[k] = nil
	end
	diskImageCache = {}
	imCacheClear()	
end

function _readCacheDir(search_root)
	log:info("_readCacheDir", " ", search_root)

	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				diskImageCache[parts[1]] = search_root .. "/" .. entry
				log:debug("readCacheDir: ", parts[1], " ", diskImageCache[parts[1]])
			end
		end
	end
end

function npSettings(tbl, vusettings, spsettings)
	npvumeters = vusettings
	for k, v in pairs(spsettings) do
		if type(v) == "boolean" then
			npspectrums[k] = {enabled=v}
		else
			if v.spType == SPT_COLOUR then
			end
			npspectrums[k] = v
		end
	end
end


function setVisSettings(tbl, settings)
    visSettings = settings
    log:info("setVisSettings: ", settings, " ", visSettings.randomSequence)
end

function initialiseCache()
	cacheClear()
	local search_root
	-- find and use artwork resized ahead of time offline 
	for search_root in findPaths("../../assets/resized") do
		_readCacheDir(search_root)
	end
	-- find and use artwork resized ahead of time offline 
	for search_root in findPaths("assets/resized") do
		_readCacheDir(search_root)
	end

	_readCacheDir(resizedCachePath)
end

function initialiseVUMeters()
	initVuMeterList()
	for k, v in pairs(npvumeters) do
		-- set flags but do not cache
		selectVuImage({},k,v, resizeAtStartUp)
	end
	local enabled = false
	for i, v in ipairs(vuImages) do
		enabled = enabled or v.enabled
	end
	if not enabled and #vuImages > 0 then
		vuImages[1].enabled = true
	end
end

function initialiseSpectrumMeters()
	initSpectrumList()
	for k, v in pairs(npspectrums) do
		-- set flags but do not cache
		selectSpectrum({}, k, v.enabled, resizeAtStartUp)
	end
	for i, v in ipairs(spectrumList) do
		enabled = enabled or v.enabled
	end
	if not enabled and #spectrumList > 0 then
		spectrumList[1].enabled = true
	end
end

function initialise()
	platformDetect()
	initialiseCache()
	initialiseVUMeters()
	initialiseSpectrumMeters()
	spBump()
	vuBump()
end

-------------------------------------------------------- 
--- image scaling 
-------------------------------------------------------- 
-- scale an image to fit a height - maintaining aspect ratio if required
function _scaleSpectrumImage(imgPath, w, h, retainAR)
	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h)
	local img = Surface:loadImage(imgPath)
	log:debug("scaleSpectrumImage: got img")
	local scaledImg
	local srcW, srcH = img:getSize()
	if srcW == w and h == srcH then
		log:debug("scaleSpectrumImage no scaling", img)
		return img
	end
	local retImg = img:resize(w, h)
	if retainAR == false then
		log:info("scaleSpectrumImage:", srcW, "x", srcH, " to ", w, "x", h)
		img:release()
		return retImg
	end
	
	-- scale + centered crop
	local scaleF = math.max(w/srcW, h/srcH)
	local scaledW = math.floor(srcW*scaleF)
	local scaledH = math.floor(srcH*scaleF)
	scaledImg = img:resize(scaledW, scaledH)
	img:release()
	log:info("scaleSpectrumImage: scale factor: ", scaleF)
	log:info("scaleSpectrumImage:blitClip",math.floor((scaledW-w)/2),", ",math.floor((scaledH-h)/2), ",", w, ", ", h, " -> ", 0, ",", 0)
	scaledImg:blitClip(math.floor((scaledW-w)/2), math.floor((scaledH-h)/2), w, h, retImg, 0, 0)
	scaledImg:release()
	return retImg
end

-- scale an image to fit a width - maintaining aspect ratio 
function _scaleAnalogVuMeter(imgPath, w_in, h, seq)
	local w = w_in
	log:debug("_scaleAnalogVuMeter imgPath:", imgPathi, " START" )
	-- FIXME hack for screenwidth > 1280 
	-- resizing too large segfaults so VUMeter resize is capped at 1280
	if w > 1280 then
		log:debug("_scaleAnalogVuMeter !!!!! w > 1280 reducing to 1280 !!!!! ", imgPath )
		w = 1280
	end
	local img = Surface:loadImage(imgPath)
	log:debug("_scaleAnalogVuMeter loaded:", imgPath)
	local srcW, srcH = img:getSize()
	local wSeq = math.floor((w/2))*seq
	-- try scaling to fit width
	local scaledH = math.floor(srcH * (wSeq/srcW))
	log:debug("_scaleAnalogVuMeter srcW:", srcW, " srcH:", srcH, " -> wSeq:", wSeq, " h:", h, " scaledH:", scaledH)
	if wSeq == srcW and h == srcH then
		log:debug("_scaleAnalogVuMeter imgPath:", imgPath, " DONE" )
		return img
	-- after scaling:
	elseif scaledH > h then
	-- doesn't fit height-wise, so ...
	-- scale to fit height - typically this means more visible empty space horizontally
		scaledH = h
		wSeq = math.floor((srcW * (h/srcH))/seq) * seq
		log:debug("_scaleAnalogVuMeter adjusted for height srcW:", srcW, " srcH:", srcH, " -> wSeq:", wSeq, " h:", h, " scaledH:", scaledH)
	end
	scaledImg = img:resize(wSeq, scaledH)
	img:release()
	log:debug("_scaleAnalogVuMeter imgPath:", imgPath, " DONE" )
	return scaledImg
end


-------------------------------------------------------- 
--- Spectrum 
-------------------------------------------------------- 
local spImageIndex = 1
local spectrumImagesMap = {}
local spectrumResolutions = {}

function registerSpectrumResolution(tbl, w,h)
	log:debug("registerSpectrumResolution", w, " x ", h)
	table.insert(spectrumResolutions, {w=w, h=h})
end


function getSpectrumList()
	return spectrumList
end

function getSpectrumSettings()
	settings = {}
	for k,v in ipairs(spectrumList) do
		settings[v.name]={enabled=v.enabled, spType=v.spType, barColor=v.barColor, capColor=v.capColor}
	end
	return settings
end

-- Workaround for mono-colour spectrums
-- if not present in settings add them
-- if present in settings then use those settings
function initColourSpectrums()
	local csp ={
		{name="mc-White", enabled=false, spType=SPT_COLOUR,		barColor=0xd0d0d0ff, capColor=0xffffffff},
		{name="mc-White translucent", enabled=false, spType=SPT_COLOUR,	barColor=0xd0d0d0a0, capColor=0xd0d0d0ff},
		{name="mc-Yellow", enabled=false, spType=SPT_COLOUR,	   barColor=0xd0d000ff, capColor=0xffff00ff},
		{name="mc-Yellow translucent", enabled=false, spType=SPT_COLOUR,   barColor=0xd0d000a0, capColor=0xd0d000ff},
		{name="mc-Cyan", enabled=false, spType=SPT_COLOUR,		 barColor=0x00d0d0ff, capColor=0x00ffffff},
		{name="mc-Cyan translucent", enabled=false, spType=SPT_COLOUR,	 barColor=0x00d0d0a0, capColor=0x00d0d0ff},
		{name="mc-Magenta", enabled=false, spType=SPT_COLOUR,	  barColor=0xd000d0ff, capColor=0xff00ffff},
		{name="mc-Magenta translucent", enabled=false, spType=SPT_COLOUR,  barColor=0xd000d0a0, capColor=0xd000d0ff},
		{name="mc-Black", enabled=false, spType=SPT_COLOUR,		barColor=0x101010ff, capColor=0x000000ff},
		{name="mc-Black translucent", enabled=false, spType=SPT_COLOUR,	barColor=0x000000a0, capColor=0x000000ff},
		{name="mc-Green", enabled=false, spType=SPT_COLOUR,		barColor=0x00d000ff, capColor=0x00d000ff},
		{name="mc-Green translucent", enabled=false, spType=SPT_COLOUR,	barColor=0x00d000a0, capColor=0x00ff00ff},
		{name="mc-Blue", enabled=false, spType=SPT_COLOUR,		 barColor=0x0000d0ff, capColor=0x0000ffff},
		{name="mc-Blue translucent", enabled=false, spType=SPT_COLOUR,	 barColor=0x0000d0a0, capColor=0x0000ffff},
		{name="mc-Red", enabled=false, spType=SPT_COLOUR,		  barColor=0xd00000ff, capColor=0xff0000ff},
		{name="mc-Red translucent", enabled=false, spType=SPT_COLOUR,	  barColor=0xd00000a0, capColor=0xff0000ff},
	}
	for x,c in pairs(csp) do
		for k, v in pairs(npspectrums) do
			if v.spType == SPT_COLOUR then
				if c.name == k then
					c.enabled = v.enabled
					c.barColor = v.barColor
				 c.capColor = v.capColor
				end
--				table.insert(spectrumList, {name=k, enabled=v.enabled, spType=v.spType, barColor=v.barColor, capColor=v.capColor})
			end
		end
		table.insert(spectrumList, c)
	end
end

--FIXME make idempotent
function _populateSpectrumBacklitList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				local imgName = 'bl-' .. parts[1]
				local bgImgName = "bg-" .. imgName
				if spectrumImagesMap[imgName] == nil then
					table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_BACKLIT})
				end
				log:debug(" SpectrumImage :", imgName, " ", bgImgName, ", ", search_root .. "/" .. entry)
				spectrumImagesMap[imgName] = {fg=imgName, bg=bgImgName, src=search_root .. "/" .. entry}
			end
		end
	end
end

function _scanSpectrumBacklitList(rpath)
	local search_root
	for search_root in findPaths(rpath) do
		_populateSpectrumBacklitList(search_root)
	end
end

--FIXME make idempotent
function _populateSpectrumImageList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				local imgName = 'im-' .. parts[1]
				if spectrumImagesMap[imgName] == nil then
					table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_GRADIENT})
				end
				log:debug(" SpectrumImage :", imgName, ", ", search_root .. "/" .. entry)
				spectrumImagesMap[imgName] = {fg=imgName, bg=nil, src=search_root .. "/" .. entry}
			end
		end
	end
end

function _scanSpectrumImageList(rpath)
	local search_root
	for search_root in findPaths(rpath) do
		_populateSpectrumImageList(search_root)
	end
end

function initSpectrumList()
	spectrumList = {}
	spectrumImagesMap = {}
	if #npspectrums == 0 then
		table.insert(spectrumList, {name=" default", enabled=false, spType=SPT_DEFAULT})
	end

	initColourSpectrums()

	local relativePath = "assets/visualisers/spectrum/backlit"
	_scanSpectrumBacklitList("../../" .. relativePath)
	_scanSpectrumBacklitList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateSpectrumBacklitList(workSpace .. "/" .. relativePath)
	end

	relativePath = "assets/visualisers/spectrum/gradient"
	_scanSpectrumImageList("../../" .. relativePath)
	_scanSpectrumImageList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateSpectrumImageList(workSpace .. "/" .. relativePath)
	end
	table.sort(spectrumList, function (left, right) return left.name < right.name end)
end

function _cacheSpectrumImage(imgName, path, w, h, spType)
	if path == nil then
		return
	end
	log:debug("cacheSpectrumImage ", imgName, ", ", path, ", ", w, ", ", h, " spType ", spType)
	local bgImgName = nil
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. imgName
	local dcpath = diskImageCache[dicKey]
	local bgDicKey = nil
	local bg_dcpath = nil

	local suffix = "bmp"
	if saveAsPng then
		suffix = "png"
	end
	-- for backlit we synthesize the backgorund
	-- image from the foreground image, and render the foreground
	-- on top of the background image
	if spType == SPT_BACKLIT then
   		-- FIXME: using pngs for backlit spectrum meters
		-- results in black screens on rpi zero 2 - works fine on desktop
		-- possibly because PNGs have an alpha channel?.
	 	suffix = "bmp" 
		local bgImgName = "bg-" .. imgName
		bgDicKey = "for-" .. w .. "x" .. h .. "-" .. bgImgName
		bg_dcpath = cachedPath(bgDicKey, suffix)
	end
	if dcpath == nil then
		local img = _scaleSpectrumImage(path, w, h, spType == SPT_BACKLIT)
		local fgimg = Surface:newRGB(w, h)
		img:blit(fgimg, 0, 0, 0)
		dcpath = cachedPath(dicKey, suffix)
		-- diskImageCache[dicKey] = img
		saveImage(fgimg, dcpath, suffix == "png")
		img:release()
		diskImageCache[dicKey] = dcpath
		log:debug("cacheSpectrumImage cached ", dicKey)
	else
		log:debug("cacheSpectrumImage found cached ", dcpath)
	end
end

function populateSpSeq()
	local indx = 1
	for i = 1, #spectrumList do
		if spectrumList[i].enabled == true then
		 spSeq[indx] = i
			indx = indx + 1
		end
	end
end

local spSeqIndex = 1
function spBump(tbl, spType)
	if #spSeq == 0 then
		populateSpSeq()
		ShuffleInPlace(spSeq)
	    spSeqIndex = #spSeq +1
	end

	if spSeqIndex > #spSeq then
		spSeqIndex = 1
		ShuffleInPlace(spSeq)
	end
	spImageIndex = spSeq[spSeqIndex]
	spSeqIndex = spSeqIndex + 1
	return true
end

function spFindSpectrumByType(spType)
	for i = 1, #spectrumList do
		if spType == nil or spectrumList[i].spType == spType then 
			log:debug("spFindSpectrumByType is ", i, " of ", #spectrumList, ", ", spectrumList[i].name)
			return spectrumList[i].name
		end
	end
	-- type is not available - return type
	return spectrumList[1].name
end

local currentFgImage = nil
local currentFgImageKey = nil
function _getFgSpectrumImage(spkey, w, h, spType)
	if spectrumImagesMap[spkey] == nil then
		return nil
	end
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg)
	if spectrumImagesMap[spkey].fg == nil then
		return nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].fg
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg, " ", dicKey)

	if currentFgImageKey == dicKey then
		return currentFgImage
	end
	if currentFgImage ~= nil then
		currentFgImage = nil
		currentFgImageKey = nil
	end
	if diskImageCache[dicKey] ~= nil then 
		log:debug("getFgImage: load ", dicKey, " ", diskImageCache[dicKey])
		currentFgImage = loadImage(diskImageCache[dicKey])
		currentFgImageKey = dicKey
	else
		-- this is required to create cached images when skin change, changes the resolution.
		if spectrumImagesMap[spkey].src ~= nil then
			_cacheSpectrumImage(spkey, spectrumImagesMap[spkey].src, w, h, spType)
			if diskImageCache[dicKey] == nil then 
				spectrumImagesMap[spkey].src = nil
				return nil
			end
			currentFgImage = loadImage(diskImageCache[dicKey])
			currentFgImageKey = dicKey
		end
	end
	return currentFgImage
end

local currentBgImage = nil
local currentBgImageKey = nil
function _getBgSpectrumImage(spkey, w, h, spType) 
	if spectrumImagesMap[spkey] == nil then
		return nil
	end
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg)
	if spectrumImagesMap[spkey].bg == nil then
		return nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].bg
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg, " ", dicKey)
	if currentBgImageKey == dicKey then
		return currentBgImage
	end
	if currentBgImage ~= nil then
		currentBgImage = nil
		currentBgImageKey = nil
	end

	currentBgImage = imCacheGet(dicKey)
	if currentBgImage ~= nil then
		currentBgImageKey = dicKey
		return currentBgImage
	end

	local fgimg = _getFgSpectrumImage(spkey, w, h, spType)
	-- FIXME:
	-- Odd: it appears that when invoking blitAlpha from the foreground image to the background image,
	-- the foreground image is affected by the alpha value.
	-- For now work around by isolating, blit foreground to a temporary image and then blitAlpha
	-- from the temporary image to the background image
	local tmp = Surface:newRGB(w,h)
	tmp:filledRectangle(0,0,w,h,0)
	fgimg:blit(tmp, 0, 0)
	currentBgImage = Surface:newRGB(w,h)
	tmp:blitAlpha(currentBgImage, 0, 0, getBacklitAlpha())
	tmp:release()
	currentBgImageKey = dicKey
	imCachePut(dicKey, currentBgImage)
	return currentBgImage
end

function getSpectrum(tbl, w, h, spType)
	log:debug("getSpectrum: ", w, " ", h)
	local spkey = spectrumList[spImageIndex].name
	if not spectrumList[spImageIndex].enabled or (spType ~= nil and spectrumList[spImageIndex].spType ~= spType) then
--		if not spBump(nil, spType) then
--			spkey = spFindSpectrumByType(spType)
--		else
--			spkey = spectrumList[spImageIndex].name
--		end
		spBump(nil, nil)
	end
	log:debug("getSpectrum: spkey: ", spkey)
	alpha = getBacklitAlpha()
	if currentFgImage ~= nil then
		currentFgImage = nil
		currentFgImageKey = nil
	end
	if currentBgImage ~= nil then
		currentBgImage = nil
		currentBgImageKey = nil
	end

	if visSettings.cacheEnabled == false then
		imCacheClear()
	end

	fg = _getFgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	bg = _getBgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	return fg, bg, alpha, spectrumList[spImageIndex].barColor, spectrumList[spImageIndex].capColor
end

function selectSpectrum(tbl, name, selected, allowCaching)
	n_enabled = 0
	log:debug("selectSpectrum", " ", name, " ", selected)
	for k, v in pairs(spectrumList) do
		if v.name == name then
			if (allowCaching and selected) or resizeAll then
					if spectrumImagesMap[name] ~= nil then
						-- create the cached image for skin resolutions 
						for kr, vr in pairs(spectrumResolutions) do
							if spectrumImagesMap[name].src ~= nil then
								_cacheSpectrumImage(name, spectrumImagesMap[name].src, vr.w, vr.h, v.spType)
							end
						end
					end
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectSpectrum", " enabled count: ", n_enabled)
	spSeq = {}
	spBump()
	return n_enabled
end

function isCurrentSpectrumEnabled()
	return spectrumList[spImageIndex].enabled
end

function getBacklitAlpha()
	return visSettings.spectrum.backlitAlpha
end

-------------------------------------------------------- 
--- Spectrum bars format
-------------------------------------------------------- 
function getBarsFormat()
	log:debug("getBarsFormat", " ", visSettings.spectrum.barsFormat.name)
	return visSettings.spectrum.barsFormat
end

-------------------------------------------------------- 
--- Spectrum caps
-------------------------------------------------------- 
function getCapsValues(tbl, capsHeight, capsSpace)
	if not visSettings.spectrum.capsOn then
		return {0,0}, {0,0}
	end
	return capsHeight, capsSpace
end

-------------------------------------------------------- 
--- Spectrum baseline
-------------------------------------------------------- 
function getBaselineValues(tbl)
	return visSettings.spectrum.baselineAlways, visSettings.spectrum.baselineOn
end


-------------------------------------------------------- 
--- Spectrum turbine
-------------------------------------------------------- 
function getSpectrumTurbine(tbl)
	log:debug("getSpectrumTurbine", " ", visSettings.spectrum.turbine)
	return visSettings.spectrum.turbine
end

--------------------------------------------------------- 
--- Spectrum channel flip
-------------------------------------------------------- 
function getChannelFlipValues()
	log:debug("getChannelFlipValues", " ", visSettings.spectrum.channelFlip.name, " ", visSettings.spectrum.channelFlip.values)
	return visSettings.spectrum.channelFlip.values
end

-------------------------------------------------------- 
--- VU meter
-------------------------------------------------------- 
local vuImageIndex = 1
local vuImagesMap = {}
local vuMeterResolutions = {}

function registerVUMeterResolution(tbl, w,h)
	log:debug("registerVUMeterResolution ", w, " x ", h)
	table.insert(vuMeterResolutions, {w=w, h=h})
end

function getVUImageList()
	return vuImages
end

function _cacheVUImage(imgName, path, w, h)
	log:debug("cacheVuImage ",  imgName, ", ", path, ", ", w, ", ", h)
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. imgName
	local dcpath = diskImageCache[dicKey]
	if dcpath == nil then
		local img = _scaleAnalogVuMeter(path, w, h, 25)
		local suffix = "bmp"
		if saveAsPng then
			suffix = "png"
		end
		dcpath = cachedPath(dicKey, suffix)
		--diskImageCache[dicKey] = img
		saveImage(img, dcpath, suffix == "png")
		diskImageCache[dicKey] = dcpath
	else
		log:debug("_cacheVuImage found cached ", dcpath)
	end
end

function _populateVfdVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				path = search_root .. "/" .. entry
				for f in lfs.dir(path) do
					mode = lfs.attributes(path .. "/" .. f, "mode")
					if mode == "file" then
						local parts = _parseImagePath(f)
						if parts ~= nil then
							log:debug("VFD ", entry .. ":" .. parts[1], "  ", path .. "/" .. f)
							diskImageCache[entry .. ":" .. parts[1]] = path .. "/" .. f
						end
					end
				end
				table.insert(vuImages, {name=entry, enabled=false, displayName=entry, vutype="vfd"})
			end
		end
	end
end

function _initVfdVuMeterList(rpath)
	local search_root
	for search_root in findPaths(rpath) do
		_populateVfdVuMeterList(search_root)
	end
end

function _populateAnalogueVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				local imgName = parts[1]
				local displayName = imgName
				local ixSub = string.find(imgName, "25seq")
				if ixSub ~= nil then
					if string.find(imgName, "25seq_") ~= nil or string.find(imgName, "25seq-") ~= nil then
						displayName = string.sub(imgName, ixSub + 6)
					else
						displayName = string.sub(imgName, ixSub + 5)
					end
				end
				log:debug("Analogue VU meter :", imgName, " ", displayName, ", ", search_root .. "/" .. entry)
				table.insert(vuImages, {name=imgName, enabled=false, displayName=displayName, vutype="frame"})
				vuImagesMap[imgName] = {src=search_root .. "/" .. entry}
			end
		end
	end
end

function _initAnalogueVuMeterList(rpath)
	local search_root
	for search_root in findPaths(rpath) do
		_populateAnalogueVuMeterList(search_root)
	end
end

function initVuMeterList()
	vuImages = {}
	vuImagesMap = {}

	local relativePath = "assets/visualisers/vumeters/vfd"
	_initVfdVuMeterList("../../" .. relativePath)
	_initVfdVuMeterList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateVfdVuMeterList(workSpace .. "/" .. relativePath)
	end
	local relativePath = "assets/visualisers/vumeters/analogue"
	_initAnalogueVuMeterList("../../" .. relativePath)
	_initAnalogueVuMeterList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateAnalogueVuMeterList(workSpace .. "/" .. relativePath)
	end
	table.sort(vuImages, function (left, right) return left.displayName < right.displayName end)
end

function populateVuSeq()
	local indx = 1
	for i = 1, #vuImages do
		if vuImages[i].enabled == true then
			vuSeq[indx] = i
			indx = indx + 1
		end
	end
end

local vuSeqIndex = 1
function vuBump()
	if #vuSeq == 0 then
		populateVuSeq()
		ShuffleInPlace(vuSeq)
	    vuSeqIndex = #vuSeq +1
	end
	if vuSeqIndex > #vuSeq then
		vuSeqIndex = 1
		ShuffleInPlace(vuSeq)
	end
	vuImageIndex = vuSeq[vuSeqIndex]
	vuSeqIndex = vuSeqIndex + 1
end

local currentVuImage = nil
local currentVuImageKey = nil
function getVuImage(w,h)
	log:debug("getVuImage ", vuImageIndex, ", ", vuImages[vuImageIndex])
	if vuImages[vuImageIndex].enabled == false then
		vuBump()
	end
	local entry = vuImages[vuImageIndex]
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. entry.name
	log:info("VUImage keys : current ", currentVuImageKey, " new: ", dicKey)
	if currentVuImageKey == dicKey then
		if entry.vutype ~= "frame" then
			-- FIXME: this will retrieve the vfd from vfdCache 
			-- need to return a complex type which can contains
			-- VUImage types 
			return  getVFDVUmeter(entry.name, w, h), entry.vutype
		end
		-- image is the current one
		log:info("returning : currentVuImage ", currentVuImage, " ", currentVuImageKey)
		return currentVuImage, entry.vutype
	end

	if visSettings.cacheEnabled == false then
		imCacheClear()
	end

	if entry.vutype ~= "frame" then
		currentVuImageKey = dicKey
		log:info("SETT VUImage keys : current ", currentVuImageKey, " new: ", dicKey)
		return  getVFDVUmeter(entry.name, w, h), entry.vutype
	end

	currentVuImage = nil
	currentVuImageKey = nil

	if diskImageCache[dicKey] ~= nil then 
		-- image is in the cache load and return
		log:debug("getVuImage: load ", dicKey, " ", diskImageCache[dicKey])
		currentVuImage = loadImage(diskImageCache[dicKey])
		currentVuImageKey = dicKey
	else
		-- this is required to create cached images when skin change, changes the resolution.
		if vuImagesMap[entry.name].src ~= nil then
			log:debug("getVuImage: creating image for ", dicKey)
			_cacheVUImage(entry.name, vuImagesMap[entry.name].src, w, h)
			if diskImageCache[dicKey] == nil then
				-- didn't work zap the src string so we don't do this repeatedly
				log:debug("getVuImage: failed to create image for ", dicKey)
				vumImagesMap[entry.name].src = nil
			end
			log:debug("getVuImage: load (new) ", dicKey, " ", diskImageCache[dicKey])
			currentVuImage = loadImage(diskImageCache[dicKey])
			currentVuImageKey = dicKey
		else
			log:debug("getVuImage: no image for ", dicKey)
		end
	end
	return currentVuImage, entry.vutype
end


function selectVuImage(tbl, name, selected, allowCaching)
	n_enabled = 0
	log:debug("selectVuImage", " ", name, " ", selected)
	for k, v in pairs(vuImages) do
		if v.name == name then
			if (allowCaching and selected) or resizeAll then
				if v.vutype == "frame" then
						-- create the cached image for skin resolutions 
						for kr, vr in pairs(vuMeterResolutions) do
							_cacheVUImage(name, vuImagesMap[name].src, vr.w, vr.h)
						end
				end
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectVuImage", " enabled count: ", n_enabled)
	vuSeq = {}
	vuBump()
	return n_enabled
end

function isCurrentVUMeterEnabled()
	return vuImages[vuImageIndex].enabled
end


function _resizedVFDElement(key, w, h)
	local img = loadImage(diskImageCache[key]):resize(w, h)
	imCachePut(key .. "-" .. w .. "x" .. h, img)
	return img
end

-- FIXME: vfdCache should go through imCache
function getVFDVUmeter(name, w, h)
	local key = name .. w .. "x" .. h
	vfd = vfdCache[key]
	if vfd ~= nil then
		log:info("vfdCache -> ", key, vfd)
		return vfd
	end
	local bar_on = name .. ":bar-on"
	local bar_off = name .. ":bar-off"
	local bar_peak_on = name .. ":bar-peak-on"
	local bar_peak_off = name .. ":bar-peak-off"
	local left = name .. ":left"
	local right = name .. ":right"
	local center = name .. ":center"
	vfd = {}
	-- bar render x-offset
	vfd.on = loadImage(diskImageCache[bar_on])
	vfd.off = loadImage(diskImageCache[bar_off])
	vfd.peakon = loadImage(diskImageCache[bar_peak_on])
	vfd.peakoff = loadImage(diskImageCache[bar_peak_off])
	vfd.leftlead = loadImage(diskImageCache[left])
	vfd.rightlead = loadImage(diskImageCache[right])
	vfd.center = loadImage(diskImageCache[center])

	local bw, bh = vfd.on:getSize()
	local lw, lh = vfd.leftlead:getSize()
	local cw, ch = vfd.center:getSize()
	local dw = cw
	local dh = ch + (bh * 2)
	local barwidth = math.floor((cw - lw)/49)
--	log:debug("#### bw:", bw, " barwidth:", barwidth)
	-- vfd.bar_rxo= barwidth - bw
	vfd.bar_rxo= 0

--	log:debug("#### dw:", dw, " dh:", dh, " w:", w, " h:", h)
--	log:debug("#### ",lw, ",", lh, "  ", bw, ",", bh, "  ", cw, "," , ch)
	if w > dw and h >= dh then
		vfd.w = dw
		vfd.h = dh
	else
		local sf = math.min((w-20)/dw, h/dh)
		barwidth = math.floor(barwidth * sf)
		bw = math.floor(bw * sf)
		bh = math.floor(bh * sf)
		lw = math.floor(lw * sf)
		lh = math.floor(lh * sf)
		-- doh. Due to rounding differences,  scaling the calibration part like so
		-- cw = math.floor((cw*w)/dw)
		-- scales at odds with the smaller bits.
		cw = math.floor((barwidth *49) + (lw *2))
		ch = math.floor((ch * sf))
		-- vfd.bar_rxo= barwidth - bw
		vfd.on = _resizedVFDElement(bar_on, bw, bh)
		vfd.off = _resizedVFDElement(bar_off, bw, bh)
		vfd.peakon = _resizedVFDElement(bar_peak_on, bw, bh)
		vfd.peakoff = _resizedVFDElement(bar_peak_off, bw, bh)
		vfd.leftlead = _resizedVFDElement(left, lw, lh)
		vfd.rightlead = _resizedVFDElement(right, lw, lh)
		vfd.center = _resizedVFDElement(center, cw, ch)
		vfd.w = cw
		vfd.h = ch + (bh * 2)
	end
	vfd.barwidth = barwidth
	vfd.bw = bw
	vfd.bh = bh
	vfd.lw = lw
	vfd.lh = lh
	vfd.cw = cw
	vfd.ch = ch
--	log:debug("####  vfd.w:", vfd.w, " vfd.h:", vfd.h)
--	log:debug("####  vfd.bw:", vfd.bw, " vfd.bh:", vfd.bh, " vfd.lw:", vfd.lw, " vfd.lh", vfd.lh, " vfd.cw:", vfd.cw, " vfd.ch", vfd.ch)
	log:info("vfdCache <- ", key, vfd)
	vfdCache[key] = vfd
	return vfd
end

------------------------------------------------------- 
--- Misc
-------------------------------------------------------- 

function sync()
	if not vuImages[vuImageIndex].enabled then
		vuBump()
	end
	if not spectrumList[spImageIndex].enabled then
		spBump(nil,nil)
	end
end

-------------------------------------------------------
--- Resize
-------------------------------------------------------
function resizeSpectrumMeter(tbl, name)
	log:info("resizeSpectrums ", name)
	for k, v in pairs(spectrumList) do
--		if v.enabled and (name == nil or name == v.name) then
		if name == v.name then
			-- create the resized images for skin resolutions 
			for kr, vr in pairs(spectrumResolutions) do
				if spectrumImagesMap[v.name].src ~= nil then
				 log:info("resizing spectrum ", v.name, " -> ", vr.w, "x", vr.h)
					_cacheSpectrumImage(v.name, spectrumImagesMap[v.name].src, vr.w, vr.h, v.spType)
					log:info("resizing done ", v.name, " -> ", vr.w, "x", vr.h)
				end
			end
		end
	end
end

function resizeVuMeter(tbl, name)
	log:info("resizeVuMeters ", name)
	for k, v in pairs(vuImages) do
--		if v.enabled and (name == nil or name == v.name) then
		if name == v.name then
			if v.vutype == "frame" then
					-- create the resized images for skin resolutions 
					for kr, vr in pairs(vuMeterResolutions) do
						log:info("resizing Vu Meter", v.name, " -> ", vr.w, "x", vr.h)
						_cacheVUImage(v.name, vuImagesMap[v.name].src, vr.w, vr.h)
					end
			end
		end
	end
end
