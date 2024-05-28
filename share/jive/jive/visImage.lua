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
local vuSeq = {}
local spSeq = {}
local visSettings = {}

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
		saveResizedImages = boolOsEnv("JL_SAVE_RESIZED_IMAGES", true)
		-- save as png is the exception - it must be explicitly disabled
		-- saveAsPng = boolOsEnv("JL_SAVE_AS_PNG", false)
	end
	-- To support saving resized visualiser images
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
		if path == nil then
			return nil
		end
		img = Surface:altLoadImage(path)
		imCachePut(path,img)
	end
	return img
end

function saveImage(img, path, asPng)
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

function cacheDelete(tbl)
	log:info("cacheDelete ")
	for k,v in pairs(diskImageCache) do
		log:info("cacheDelete ", k, " ", v)
		os.execute('rm  ' .. '"'.. v .. '"') 
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


function setVisSettings(tbl, settings)
	visSettings = settings

	platformDetect()
	initialiseCache()

	initSpectrumList()
	local enabled_count = 0
	local k,v 
	for k, v in pairs(settings.spectrumMeterSelection) do
		-- set flags but do not cache
		selectSpectrum(nil, k, v, false)
		if v then
			enabled_count = enabled_count + 1
		end
	end
	if enabled_count == 0 and #spectrumList > 0 then
		-- try to select a default which does require a resize
		-- 1: try white colour
		for k, v in pairs(spectrumList) do
			if v.name == "mc-White" and v.spType == "colour" then
				v.enabled = true
				enabled_count = 1
			end
		end
		if enabled_count == 0 then
			-- 2: try a colour
			for k, v in pairs(spectrumList) do
				if v.spType == "colour" then
					v.enabled = true
					enabled_count = 1
					break
				end
			end
		end
		if enabled_count == 0 then
			-- 3: finally just use whatever is first in the list
			-- a resize may be involved at a later stage
			spectrumList[1].enabled = true
		end
	end

	initVuMeterList()
	enabled_count = 0
	for k, v in pairs(settings.vuMeterSelection) do
		-- set flags but do not cache
		selectVuImage(nil, k, v , false)
		if v then
			enabled_count = enabled_count + 1
		end
	end
	if enabled_count == 0 and #vuImages > 0 then
		-- select a default try to find a vfd (no resize required)
		-- 1: try "RS-M250"
		for k, v in pairs(vuImages) do
			if v.name == "RS-M250" and v.vutype=="vfd" then
				v.enabled = true
				enabled_count = 1
			end
		end
		if enabled_count == 0 then
			-- 2: try any VFD
			for k, v in pairs(vuImages) do
				if v.vutype=="vfd" then
					v.enabled = true
					enabled_count = 1
					break
				end
			end
		end
		if enabled_count == 0 then
			-- 3: finally just use whatever is first in the list
			-- a resize may be involved at a later stage
			vuImage[1].enabled = true
		end
	end
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

function initialise()
	__spBump()
	__vuBump()
end

-------------------------------------------------------- 
--- image scaling 
-------------------------------------------------------- 
-- scale an image to fit a height - maintaining aspect ratio if required
function _scaleSpectrumImage(imgPath, w, h, retainAR)
	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h)
	local img = Surface:altLoadImage(imgPath)
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
		img = nil
		return retImg
	end
	
	-- scale + centered crop
	local scaleF = math.max(w/srcW, h/srcH)
	local scaledW = math.floor(srcW*scaleF)
	local scaledH = math.floor(srcH*scaleF)
	scaledImg = img:resize(scaledW, scaledH)
	img:release()
	img = nil
	log:info("scaleSpectrumImage: scale factor: ", scaleF)
	log:info("scaleSpectrumImage:blitClip",math.floor((scaledW-w)/2),", ",math.floor((scaledH-h)/2), ",", w, ", ", h, " -> ", 0, ",", 0)
	scaledImg:blitClip(math.floor((scaledW-w)/2), math.floor((scaledH-h)/2), w, h, retImg, 0, 0)
	scaledImg:release()
	scaledImg = nil
	return retImg
end

-- scale an image to fit a width - maintaining aspect ratio 
function _scaleAnalogVuMeter(imgPath, w_in, h, seq)
	local w = w_in
	log:debug("_scaleAnalogVuMeter imgPath:", imgPath, " START" )
	-- FIXME hack for screenwidth > 1280 
	-- resizing too large segfaults so VUMeter resize is capped at 1280
	if w > 1280 then
		log:debug("_scaleAnalogVuMeter !!!!! w > 1280 reducing to 1280 !!!!! ", imgPath )
		w = 1280
	end
	local img = Surface:altLoadImage(imgPath)
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
	img = nil
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


function getSpectrumMeterList()
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
					table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_IMAGE})
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
		fgimg:release()
		fgimg = nil
		img:release()
		img = nil
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
function __spBump(tbl, spType)
	if #spSeq == 0 then
		populateSpSeq()
		ShuffleInPlace(spSeq)
		spSeqIndex = #spSeq +1
	end

	if spSeqIndex > #spSeq then
		spSeqIndex = 1
		populateSpSeq()
		ShuffleInPlace(spSeq)
	end
	spImageIndex = spSeq[spSeqIndex]
	spSeqIndex = spSeqIndex + 1
	return true
end

function spChange(tbl, name)
	if name == "visuChangeOnTrackChange" and visSettings.visuChangeOnTrackChange then
		__spBump()
	end
	if name == "visuChangeOnNpViewChange" and visSettings.visuChangeOnNpViewChange then
		__spBump()
	end
	if name == "force" then
		__spBump()
	end
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

function _getFgSpectrumImage(spkey, w, h, spType)
	local fgImage = nil
	if spectrumImagesMap[spkey] == nil then
		return nil
	end
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg)
	if spectrumImagesMap[spkey].fg == nil then
		return nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].fg
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg, " ", dicKey)

	if diskImageCache[dicKey] ~= nil then 
		log:debug("getFgImage: load ", dicKey, " ", diskImageCache[dicKey])
		fgImage = loadImage(diskImageCache[dicKey])
---- if a resized image is not found then return nil, resizing implicitly yields a poor user experience
--	else
--		-- this is required to create cached images when skin change, changes the resolution.
--		if spectrumImagesMap[spkey].src ~= nil then
--			_cacheSpectrumImage(spkey, spectrumImagesMap[spkey].src, w, h, spType)
--			if diskImageCache[dicKey] == nil then 
--				spectrumImagesMap[spkey].src = nil
--				return nil
--			end
--			fgImage = loadImage(diskImageCache[dicKey])
--		end
	end
	return fgImage
end

function _getBgSpectrumImage(spkey, w, h, spType) 
	local bgImage = nil
	if spectrumImagesMap[spkey] == nil then
		return nil
	end
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg)
	if spectrumImagesMap[spkey].bg == nil then
		return nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].bg
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg, " ", dicKey)

	bgImage = imCacheGet(dicKey)
	if bgImage == nil then
		local fgimg = _getFgSpectrumImage(spkey, w, h, spType)
		if fgimg ~= nil then
			-- FIXME:
			-- Odd: it appears that when invoking blitAlpha from the foreground image to the background image,
			-- the foreground image is affected by the alpha value.
			-- For now work around by isolating, blit foreground to a temporary image and then blitAlpha
			-- from the temporary image to the background image
			local tmp = Surface:newRGB(w,h)
			tmp:filledRectangle(0,0,w,h,0)
			fgimg:blit(tmp, 0, 0)
			bgImage = Surface:newRGB(w,h)
			tmp:blitAlpha(bgImage, 0, 0, getBacklitAlpha())
			tmp:release()
			tmp = nil
			imCachePut(dicKey, bgImage)
		end
	end
	return bgImage
end

function getSpectrum(tbl, w, h, spType)
	log:debug("getSpectrum: ", w, " ", h)
	local spkey = spectrumList[spImageIndex].name
--	if not spectrumList[spImageIndex].enabled or (spType ~= nil and spectrumList[spImageIndex].spType ~= spType) then
--		if not __spBump(nil, spType) then
--			spkey = spFindSpectrumByType(spType)
--		else
--			spkey = spectrumList[spImageIndex].name
--		end
--		__spBump(nil, nil)
--	end
	log:debug("getSpectrum: spkey: ", spkey)
	alpha = getBacklitAlpha()

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
			if (allowCaching and selected) then
					if spectrumImagesMap[name] ~= nil then
						-- create the cached image for skin resolutions 
						for kr, vr in pairs(spectrumResolutions) do
							if spectrumImagesMap[name].src ~= nil then
								_cacheSpectrumImage(name, spectrumImagesMap[name].src, vr.w, vr.h, v.spType)
							end
						end
					end
			end
			if not selected and v.enabled then
				v.enabled = selected
				-- deselected so re-sequence
				spSeq = {}
				__spBump()
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectSpectrum", " enabled count: ", n_enabled)
--	spSeq = {}
--	__spBump()
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
	log:debug("getBarsFormat", " ", visSettings.spectrum.barsFormat)
	return visSettings.spectrum.barFormats[visSettings.spectrum.barsFormat]
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
local channelFlips  = {
		LHHL={0,1},
		HLHL={1,1},
		HLLH={1,0},
		LHLH={0,0},
}

function getChannelFlipValues()
	log:debug("getChannelFlipValues", " ", visSettings.spectrum.channelFlip, " ", channelFlips[visSettings.spectrum.channelFlip])
	return channelFlips[visSettings.spectrum.channelFlip]
end

-------------------------------------------------------- 
--- VU meter
-------------------------------------------------------- 
local vuImageIndex = 1
local vuImagesMap = {}
local vuMeterResolutions = {}
local vfdImageSources = {}

function registerVUMeterResolution(tbl, w,h)
	log:debug("registerVUMeterResolution ", w, " x ", h)
	table.insert(vuMeterResolutions, {w=w, h=h})
end

function getVuMeterList()
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
		img:release()
		img = nil
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
							vfdImageSources[entry .. ":" .. parts[1]] = path .. "/" .. f
						end
					end
				end
				table.insert(vuImages, {name=entry, enabled=false, displayName='vfd-' .. entry, vutype="vfd"})
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
						displayName = '25f-' .. string.sub(imgName, ixSub + 6)
					else
						displayName = '25f-' .. string.sub(imgName, ixSub + 5)
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
function __vuBump()
	if #vuSeq == 0 then
		populateVuSeq()
		ShuffleInPlace(vuSeq)
		vuSeqIndex = #vuSeq +1
	end
	if vuSeqIndex > #vuSeq then
		vuSeqIndex = 1
		populateVuSeq()
		ShuffleInPlace(vuSeq)
	end
	vuImageIndex = vuSeq[vuSeqIndex]
	vuSeqIndex = vuSeqIndex + 1
end

function vuChange(tbl, name)
	if name == "visuChangeOnTrackChange" and visSettings.visuChangeOnTrackChange then
		__vuBump()
	end
	if name == "visuChangeOnNpViewChange" and visSettings.visuChangeOnNpViewChange then
		__vuBump()
	end
	if name == "force" then
		__vuBump()
	end
end

function getVuImage(w,h)
	log:debug("getVuImage ", vuImageIndex, ", ", vuImages[vuImageIndex])
--	if vuImages[vuImageIndex].enabled == false then
--		__vuBump()
--	end
	local entry = vuImages[vuImageIndex]
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. entry.name

	if visSettings.cacheEnabled == false then
		imCacheClear()
	end

	if entry.vutype == "vfd" then
		return  getVFDVUmeter(entry.name, w, h), entry.vutype
	end

	local frameVU = nil

	if diskImageCache[dicKey] ~= nil then 
		-- image is in the cache load and return
		log:debug("getVuImage: load ", dicKey, " ", diskImageCache[dicKey])
		frameVU = loadImage(diskImageCache[dicKey])
---- if a resized image is not found then return nil, resizing implicitly yields a poor user experience
--	else
--		-- this is required to create cached images when skin change, changes the resolution.
--		if vuImagesMap[entry.name].src ~= nil then
--			log:debug("getVuImage: creating image for ", dicKey)
--			_cacheVUImage(entry.name, vuImagesMap[entry.name].src, w, h)
--			if diskImageCache[dicKey] == nil then
--				-- didn't work zap the src string so we don't do this repeatedly
--				log:debug("getVuImage: failed to create image for ", dicKey)
--				vumImagesMap[entry.name].src = nil
--			end
--			log:debug("getVuImage: load (new) ", dicKey, " ", diskImageCache[dicKey])
--			frameVU = loadImage(diskImageCache[dicKey])
--		else
--			log:debug("getVuImage: no image for ", dicKey)
--		end
	end
	return frameVU, entry.vutype
end


function selectVuImage(tbl, name, selected, allowCaching)
	n_enabled = 0
	log:debug("selectVuImage", " ", name, " ", selected)
	for k, v in pairs(vuImages) do
		if v.name == name then
			if (allowCaching and selected) then
				if v.vutype == "frame" then
						-- create the cached image for skin resolutions 
						for kr, vr in pairs(vuMeterResolutions) do
							_cacheVUImage(name, vuImagesMap[name].src, vr.w, vr.h)
						end
				end
			end
			if not selected and v.enabled then
				v.enabled = selected
				-- deselected so re-sequence in 
				vuSeq = {}
				__vuBump()
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectVuImage", " enabled count: ", n_enabled)
	return n_enabled
end

function isCurrentVUMeterEnabled()
	return vuImages[vuImageIndex].enabled
end


function _resizedVFDElement(srcImg, key, w, h)
	local dicKey = key .. "-" .. w .. "x" .. h
	local img =  loadImage(diskImageCache[dicKey])
	if diskImageCache[dicKey] == nil then
		img = srcImg:resize(w, h)
		local suffix = "png"
		local dcPath = cachedPath(dicKey, suffix)
		saveImage(img, dcPath, suffix == "png")
		imCachePut(dicKey, img)
	end
	srcImg:release()
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

	local r_bar_on = name .. ":r-bar-on"
	local r_bar_off = name .. ":r-bar-off"
	local r_bar_peak_on = name .. ":r-bar-peak-on"
	local r_bar_peak_off = name .. ":r-bar-peak-off"

	if vfdImageSources[r_bar_on] == nil then
		r_bar_on = bar_on
	end
	if vfdImageSources[r_bar_off] == nil then
		r_bar_off = bar_off
	end
	if vfdImageSources[r_bar_peak_on] == nil then
		r_bar_peak_on = bar_peak_on
	end
	if vfdImageSources[r_bar_peak_off] == nil then
		r_bar_peak_off = bar_peak_off
	end

	local left = name .. ":left"
	local right = name .. ":right"
	local left_trail = name .. ":left-trail"
	local right_trail = name .. ":right-trail"
	local right = name .. ":right"
	local center = name .. ":center"
	vfd = {}
	vfd.left={}
	vfd.right={}
	-- bar render x-offset
	vfd.left.on = loadImage(vfdImageSources[bar_on])
	vfd.left.off = loadImage(vfdImageSources[bar_off])
	vfd.left.peakon = loadImage(vfdImageSources[bar_peak_on])
	vfd.left.peakoff = loadImage(vfdImageSources[bar_peak_off])

	vfd.right.on = loadImage(vfdImageSources[r_bar_on])
	vfd.right.off = loadImage(vfdImageSources[r_bar_off])
	vfd.right.peakon = loadImage(vfdImageSources[r_bar_peak_on])
	vfd.right.peakoff = loadImage(vfdImageSources[r_bar_peak_off])

	vfd.leftlead = loadImage(vfdImageSources[left])
	vfd.rightlead = loadImage(vfdImageSources[right])
	vfd.lefttrail = loadImage(vfdImageSources[left_trail])
	vfd.righttrail = loadImage(vfdImageSources[right_trail])
	vfd.center = loadImage(vfdImageSources[center])

	local bw, bh = vfd.left.on:getSize()
	local lw, lh = vfd.leftlead:getSize()
	local tw, th = 0, 0
	if vfd.lefttrail ~= nil then
		tw, th = vfd.lefttrail:getSize()
	end
	local cw, ch = vfd.center:getSize()
	local dw = cw
	local dh = ch + (bh * 2)
	local barwidth = math.floor((cw - lw)/49)
	local calcbw = (cw - lw - tw)/49
--	log:debug("#### bw:", bw, " barwidth:", barwidth)
	-- vfd.bar_rxo= barwidth - bw
	vfd.left.bar_rxo= 0
	vfd.right.bar_rxo= 0
--	log:debug("#### dw:", dw, " dh:", dh, " w:", w, " h:", h)
--	log:debug("#### ",lw, ",", lh, "  ", bw, ",", bh, "  ", cw, "," , ch)
	if w > dw and h >= dh then
		vfd.w = dw
		vfd.h = dh
	else
		local sf = math.min(w/dw, h/dh)
--		log:debug("#### vfd : sf : ", sf)
		barwidth = math.floor(barwidth * sf)
		calcbw = math.floor(calcbw * sf)
		bw = math.floor(bw * sf)
		bh = math.floor(bh * sf)
		lw = math.floor(lw * sf)
		lh = math.floor(lh * sf)
		tw = math.floor(tw * sf)
		-- Due to rounding errors, scaling the calibration part like so
		cw = math.floor((cw * sf))
		-- scales at odds with the smaller bits.
--	  	log:debug("delta calc vs sf ", (calcbw *49) + lw + tw - cw)
		cw = (calcbw *49) + lw + tw
		ch = math.floor((ch * sf))
		-- vfd.bar_rxo= barwidth - bw
		vfd.left.on = _resizedVFDElement(vfd.left.on, bar_on, bw, bh)
		vfd.left.off = _resizedVFDElement(vfd.left.off, bar_off, bw, bh)
		vfd.left.peakon = _resizedVFDElement(vfd.left.peakon, bar_peak_on, bw, bh)
		vfd.left.peakoff = _resizedVFDElement(vfd.left.peakoff, bar_peak_off, bw, bh)
		vfd.right.on = _resizedVFDElement(vfd.right.on, r_bar_on, bw, bh)
		vfd.right.off = _resizedVFDElement(vfd.right.off, r_bar_off, bw, bh)
		vfd.right.peakon = _resizedVFDElement(vfd.right.peakon, r_bar_peak_on, bw, bh)
		vfd.right.peakoff = _resizedVFDElement(vfd.right.peakoff, r_bar_peak_off, bw, bh)

		vfd.leftlead = _resizedVFDElement(vfd.leftlead, left, lw, lh)
		vfd.rightlead = _resizedVFDElement(vfd.rightlead, right, lw, lh)
		vfd.center = _resizedVFDElement(vfd.center, center, cw, ch)
		vfd.w = cw
		vfd.h = ch + (bh * 2)
	end
	vfd.left.barwidth = barwidth
	vfd.right.barwidth = barwidth
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

--function sync()
--	if not vuImages[vuImageIndex].enabled then
--		__vuBump()
--	end
--	if not spectrumList[spImageIndex].enabled then
--		__spBump(nil,nil)
--	end
--end

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

function getCurrentVuMeterName()
	return '' .. vuImages[vuImageIndex].name
end

function getCurrentSpectrumMeterName()
	return '' .. spectrumList[spImageIndex].name
end

function resizeRequiredSpectrumMeter(tbl, name)
	local kr,vr, k,v
	for k, v in pairs(spectrumList) do
		if v.name == name then
			-- spectrum meter found
			if v.spType == SPT_BACKLIT or v.spType == SPT_IMAGE then
				-- of type that does require resize
				if spectrumImagesMap[name].src ~= nil then
					-- have path to source image
				   	for kr, vr in pairs(spectrumResolutions) do
						if diskImageCache["for-" .. vr.w .. "x" .. vr.h .. "-" .. name] == nil then
							return true
						end
					end
				end
			end
			-- not resizable 1) not resizable type 2) no source image
			break
		end
	end
	-- spectrum meter not resizable : not found, not resizable, no source images
	return false
end

function resizeRequiredVuMeter(tbl, name)
	local kr, vr, k, v

	for k, v in pairs(vuImages) do
		if v.name == name then
			-- found vu meter
			if v.vutype == "frame" then
				-- resizable type
				for kr, vr in pairs(vuMeterResolutions) do
					if diskImageCache["for-" .. vr.w .. "x" .. vr.h .. "-" .. name] == nil then
						return true
					end
				end
			end
			break
		end
	end
	-- vu meter not resizable : not found, not resizable
	return false
end
