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

local ipairs, pairs, pcall	= ipairs, pairs, pcall
local coroutine, package	= coroutine, package

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
SPT_GRADIENT = "gradient"

local vuImages = {}
local spectrumList = {}
local npvumeters = {}
local npspectrums = {}

-- set to true to create all resized images which can be 
-- then moved to assets/resized 
CACHE_EAGER = true
-- cache all images at startup - depending on selected images
-- this can affect startup times and on platforms like piCorePlayer
-- jivelite terminate.
local cacheAtStartup = true
-- commit cached images to disk
local saveCachedImages = true
local saveAsPng = true
local PLATFORM = ""

function _parseImagePath(imgpath)
	local parts = string.split("%.", imgpath)
	local ix = #parts
	if parts[ix] == 'png' or parts[ix] == 'jpg' or parts[ix] == 'bmp' then
-- FIXME return array of size 2 always
		return parts
	end
	return nil
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
		CACHE_EAGER = false
		cacheAtStartup = false
		saveCachedImages = false
		saveAsPng = false
	end
	log:info("PLATFORM ", PLATFORM)
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

function loadImage(path)
	img = imCacheGet(path)
	if img == nil  then
		img = Surface:loadImage(path)
		imCachePut(path,img)
	end
	return img
end

function saveImage(img, path)
	imCachePut(path, img)
	if saveCachedImages then
		if saveAsPng then
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
local userdirpath = System.getUserDir()
local cachedir = userdirpath .. "/resized_cache"

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

function cachedPath(name)
	-- we don't know/care whether it is a bmp, png or jpeg 
	-- loading the file just works 
	local file = cachedir .. "/" .. name .. ".bmp"
	return file
end

function cacheClear(tbl)
	log:debug("cacheClear ")
	for k,v in pairs(diskImageCache) do
		log:debug("cacheClear ", k)
		diskImageCache[k] = nil
	end
	
	-- FIXME vfdCache is not using imCache so 
	-- those images are not released
	for k,v in pairs(imCache) do
		v:release()
	end
end


function _readCacheDir(search_root)
	log:debug("_readCacheDir", " ", search_root)

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
	npspectrums = spsettings
end

function initialiseCache()
	cacheClear()
	local search_root
	for search_root in findPaths("../../assets/resized") do
		_readCacheDir(search_root)
	end

	for search_root in findPaths("resized_cache") do
		_readCacheDir(search_root)
	end
end

function initialiseVUMeters()
	initVuMeterList()
	for k, v in pairs(npvumeters) do
		-- set flags but do not cache
		selectVuImage({},k,v, cacheAtStartup)
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
		selectSpectrum({},k,v, cacheAtStartup)
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
end

-------------------------------------------------------- 
--- image scaling 
-------------------------------------------------------- 
-- scale an image to fit a height - maintaining aspect ration
function _scaleSpectrumImage(imgPath, w, h)
	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h)
	local img = Surface:loadImage(imgPath)
	log:debug("scaleSpectrumImage: got img")
	local scaledImg
	local srcW, srcH = img:getSize()
	if srcW == w and h == srcH then
		log:debug("scaleSpectrumImage done", img)
		return img
	end
	log:debug("scaleSpectrumImage: srcW:", srcW, " srcH:", srcH)
	-- for spectrum height is determines the scaling factor
	local scaledW = math.floor(srcW * (h/srcH))
	log:debug("scaleSpectrumImage srcW:", srcW, " srcH:", srcH, " -> w:", w, " h:", h, " scaledW:", scaledW)
	-- scale: whilst trying to maintain proportions
	-- perfect match just resize
	if scaledW == w then
		log:debug("scaleSpectrumImage simple resize")
		scaledImg = img:resize(w, h)
		log:debug("scaleSpectrumImage simple resize DONE")
	-- if scaled width is > required clip the horizontal edges
	elseif scaledW > w then
		log:debug("scaleSpectrumImage resize + hclip")
		local tmp = img:resize(scaledW, h)
		scaledImg = img:resize(w, h)
		-- upto 1 pixel smaller for odd numbered width differences
		tmp:blitClip(math.floor((scaledW-w)/2), 0, w, h, scaledImg, 0, 0)
		tmp:release()
		log:debug("scaleSpectrumImage resize + hclip DONE")
	elseif srcW > w and srcH > h then
	-- if src image is larger just clip
		log:debug("scaleSpectrumImage clip x-center y-bottom")
		scaledImg = img:resize(w, h)
		img:blitClip(math.floor((srcW-w)/2), srcH-h , w, h, scaledImg, 0, 0)
		log:debug("scaleSpectrumImage clip x-center y-bottom DONE")
	elseif srcH > h and scaledW > (w/2) then
	-- if src image is almost larger enough expand to fill horizontally
	-- and clip vertically
		log:debug("scaleSpectrumImage expand to w, clip y-center")
		local scaledH = math.floor(srcH * (w/srcW))
		local tmp = img:resize(w, scaledH)
		scaledImg = img:resize(w, h)
		tmp:blitClip(0, (scaledH-h)/2, w, h, scaledImg, 0, 0)
		tmp:release()
		log:debug("scaleSpectrumImage expand to w, clip y-center DONE")
	else
	-- if scaled width is significantly < than width the expand - this distorts proportion
	-- desired behaviour for vertically thin source images which typically would be colour
	-- gradients
		log:debug("scaleSpectrumImage resize expand H")
		scaledImg = img:resize(w, h)
	end
--	elseif srcW > w and srcH > h then
--		log:debug("scaleSpectrumImage clip x-center y-bottom")
--		scaledImg = img:resize(w, h)
--		img:blitClip(math.floor((srcW-w)/2), srcH -h , w, h, scaledImg, 0, 0)
--	else
--	-- if width > then window width then clip the source image,
--	-- this preserves proportion
--		log:debug("scaleSpectrumImage resize and clip")
--		local tmp = img:resize(scaledW, h)
--		-- FIXME: find cheaper way to create an image of wxh
--		scaledImg = img:resize(w,h)
--		tmp:blitClip(math.floor((scaledW-w)/2), 0, scaledW-w, h, scaledImg, 0, 0)
--		tmp:release()
	img:release()
	log:debug("scaleSpectrumImage DONE")
	return scaledImg
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

function initSpectrumList()
	spectrumList = {}
	spectrumImagesMap = {} 
	table.insert(spectrumList, {name=" default", enabled=false, spType=SPT_DEFAULT})
	spectrumImagesMap[" default"] = {fg=nil, bg=nil, src=nil} 

	local search_root
	for search_root in findPaths("../../assets/visualisers/spectrum/backlit") do
		for entry in lfs.dir(search_root) do
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "file" then
				local parts = _parseImagePath(entry)
				if parts ~= nil then
					local imgName = parts[1]
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

	for search_root in findPaths("../../assets/visualisers/spectrum/gradient") do
		for entry in lfs.dir(search_root) do
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "file" then
				local parts = _parseImagePath(entry)
				if parts ~= nil then
					local imgName = parts[1]
					if spectrumImagesMap[imgName] == nil then
						table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_GRADIENT})
					end
					log:debug(" SpectrumGradient :", imgName, ", ", search_root .. "/" .. entry)
					spectrumImagesMap[imgName] = {fg=imgName, bg=nil, src=search_root .. "/" .. entry}
				end
			end
		end
	end
	table.sort(spectrumList, function (left, right) return left.name < right.name end)
end

function _cacheSpectrumImage(imgName, path, w, h, spType)
	log:debug("cacheSpectrumImage ", imgName, ", ", path, ", ", w, ", ", h, " spType ", spType)
	local bgImgName = nil
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. imgName
	local dcpath = diskImageCache[dicKey]
	local bgDicKey = nil
	local bg_dcpath = nil

	-- for backlit we synthesize the backgorund
	-- image from the foreground image, and render the foreground
	-- on top of the background image
	if spType == SPT_BACKLIT then
		local bgImgName = "bg-" .. imgName
		bgDicKey = "for-" .. w .. "x" .. h .. "-" .. bgImgName
		bg_dcpath = cachedPath(bgDicKey)
	end
	if dcpath == nil then
		local img = _scaleSpectrumImage(path, w, h)
		local fgimg = Surface:newRGB(w, h)
		img:blit(fgimg, 0, 0, 0)
		dcpath = cachedPath(dicKey)
		-- diskImageCache[dicKey] = img
		saveImage(fgimg, dcpath)
		img:release()
		diskImageCache[dicKey] = dcpath
		log:debug("cacheSpectrumImage cached ", dicKey)
	else
		log:debug("cacheSpectrumImage found cached ", dcpath)
	end
end

function spBump(tbl, spType)
	for i = 1, #spectrumList do
		spImageIndex = (spImageIndex % #spectrumList) + 1
		if spectrumList[spImageIndex].enabled == true then
			if spType == nil or spectrumList[spImageIndex].spType == spType then 
				log:debug("spBump is ", spImageIndex, " of ", #spectrumList, ", ", spectrumList[spImageIndex].name)
				return true
			end
		end
	end
	return false
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
	-- if we invoke blitAlpha from the foreground image to the background image
	-- the foreground image is affected by alpha see SDL_SetAlpha.
    -- Isolate by blitting foreground to a temporary image and then blitAlpha
    -- from that to the background image
	local tmp = Surface:newRGB(w,h)
	tmp:filledRectangle(0,0,w,h,0)
	img:blit(tmp, 0, 0)
	currentBgImage = Surface:newRGB(w,h)
	tmp:blitAlpha(currentBgImage, 0, 0, getBackgroundAlpha())
	tmp:release()
	currentBgImageKey = dicKey
	imCachePut(dicKey, currentBgImage)
	return currentBgImage
end

function getSpectrum(tbl, w, h, spType)
	log:debug("getSpectrum: ", w, " ", h)
	local spkey = spectrumList[spImageIndex].name
	if not spectrumList[spImageIndex].enabled or (spType ~= nil and spectrumList[spImageIndex].spType ~= spType) then
		if not spBump(nil, spType) then
			spkey = spFindSpectrumByType(spType)
		else
			spkey = spectrumList[spImageIndex].name
		end
	end
	log:debug("getSpectrum: spkey: ", spkey)
	fg = _getFgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	bg = _getBgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	alpha = getBackgroundAlpha
	return fg, bg, alpha
end

function selectSpectrum(tbl, name, selected, allowCaching)
	n_enabled = 0
	log:debug("selectSpectrum", " ", name, " ", selected)
	for k, v in pairs(spectrumList) do
		if v.name == name then
			if (allowCaching and selected) or CACHE_EAGER then
					-- create the cached image for skin resolutions 
					for kr, vr in pairs(spectrumResolutions) do
						if spectrumImagesMap[name].src ~= nil then
							_cacheSpectrumImage(name, spectrumImagesMap[name].src, vr.w, vr.h, v.spType)
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
	return n_enabled
end

function isCurrentSpectrumEnabled()
	return spectrumList[spImageIndex].enabled
end

local bgAlpha = 40

function setBackgroundAlpha(tbl, v)
	log:debug("setBackgroundAlpha ", tbl, "; v=", v)
	bgAlpha = v
end

function getBackgroundAlpha()
	return bgAlpha
end

-------------------------------------------------------- 
--- Spectrum bars format
-------------------------------------------------------- 
local barsFormats  = {
	{name="2-1-3-6", values={barsInBin=2, barWidth=1, barSpace=3, binSpace=6}},
	{name="2-2-3-4", values={barsInBin=2, barWidth=2, barSpace=3, binSpace=4}},
	{name="2-3-3-2", values={barsInBin=2, barWidth=3, barSpace=3, binSpace=2}},
	{name="2-4-1-2", values={barsInBin=2, barWidth=4, barSpace=1, binSpace=2}},
	{name="1-4-3-6", values={barsInBin=1, barWidth=4, barSpace=3, binSpace=6}},
	{name="1-6-3-4", values={barsInBin=1, barWidth=6, barSpace=3, binSpace=4}},
	{name="1-8-3-2", values={barsInBin=1, barWidth=8, barSpace=3, binSpace=2}},
	{name="1-5-1-5", values={barsInBin=1, barWidth=5, barSpace=1, binSpace=5}},
	{name="1-5-1-3", values={barsInBin=1, barWidth=5, barSpace=1, binSpace=3}},
	{name="1-4-1-4", values={barsInBin=1, barWidth=4, barSpace=1, binSpace=4}},
	{name="1-4-1-3", values={barsInBin=1, barWidth=4, barSpace=1, binSpace=3}},
	{name="1-5-1-2", values={barsInBin=1, barWidth=5, barSpace=1, binSpace=2}},
	{name="2-2-1-2", values={barsInBin=2, barWidth=2, barSpace=1, binSpace=2}},
	{name="1-4-1-2", values={barsInBin=1, barWidth=4, barSpace=1, binSpace=2}},
	{name="1-3-1-3", values={barsInBin=1, barWidth=3, barSpace=1, binSpace=3}},
	{name="1-3-1-2", values={barsInBin=1, barWidth=3, barSpace=1, binSpace=2}},
	{name="2-1-1-2", values={barsInBin=2, barWidth=1, barSpace=1, binSpace=2}},
	{name="1-2-1-2", values={barsInBin=1, barWidth=2, barSpace=1, binSpace=2}},
	{name="1-3-1-1", values={barsInBin=1, barWidth=3, barSpace=1, binSpace=1}},
	{name="1-2-1-1", values={barsInBin=1, barWidth=2, barSpace=1, binSpace=1}},
	{name="1-1-1-1", values={barsInBin=1, barWidth=1, barSpace=1, binSpace=1}},
}

local barsFormat  = barsFormats[1]

function getBarsFormat()
	log:debug("getBarFormat", " ", barsFormat.name)
	return barsFormat
end

function getBarFormats()
	return barsFormats
end

function setBarsFormat(tbl, format)
	log:debug("setBarsFormat", " ", format.name)
	barsFormat = format
end

-------------------------------------------------------- 
--- Spectrum caps
-------------------------------------------------------- 
local capsOn  = true

function getCapsOn(tbl)
	log:debug("getCapsOn", " ", capsOn)
	return capsOn
end

function setCapsOn(tbl, v)
	log:debug("setCapsOn", " ", v)
	capsOn = v
end

function getCapsValues(tbl, capsHeight, capsSpace)
	if not capsOn then
		return {0,0}, {0,0}
	end
	return capsHeight, capsSpace
end

-------------------------------------------------------- 
--- Spectrum channel flip
-------------------------------------------------------- 
local channelFlips  = {
	{name="LF--HF, HF--LF", values={0,1}},
	{name="HF--LF, HF--LF", values={1,1}},
	{name="HF--LF, LF--HF", values={1,0}},
	{name="LF--HF, LF--HF", values={0,0}},
}

local channelFlip  = channelFlips[1]

function getChannelFlipValues()
	log:debug("getChannelFlipValues", " ", channelFlip.name, " ", channelFlip.values)
	return channelFlip.values
end

function getChannelFlip()
	log:debug("getChannelFlip", " ", channelFlip.name)
	return channelFlip
end

function getChannelFlips()
	return channelFlips
end

function setChannelFlip(tbl, flip)
	log:debug("setChannelFlip", " ", flip.name)
	channelFlip = flip
end


-------------------------------------------------------- 
--- VU meter
-------------------------------------------------------- 
local vuImageIndex = 1
local vuImagesMap = {}
local vuMeterResolutions = {}

function registerVUMeterResolution(tbl, w,h)
	log:debug("registerVUMeterResolution", w, " x ", h)
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
		dcpath = cachedPath(dicKey)
		--diskImageCache[dicKey] = img
		saveImage(img, dcpath)
		diskImageCache[dicKey] = dcpath
	else
		log:debug("_cacheVuImage found cached ", dcpath)
	end
end

function initVuMeterList()
	vuImages = {}
	vuImagesMap = {}
	local search_root
	for search_root in findPaths("../../assets/visualisers/vumeters/vfd") do
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

	-- Do this the dumb way for now, i.e. repeat the enumeration
	for search_root in findPaths("../../assets/visualisers/vumeters/analogue") do
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
	table.sort(vuImages, function (left, right) return left.name < right.name end)
end

function vuBump()
	for i = 1, #vuImages do
		vuImageIndex = (vuImageIndex % #vuImages) + 1
		if vuImages[vuImageIndex].enabled == true then
			log:debug("vuBump is ", vuImageIndex, " of ", #vuImages, ", ", vuImages[vuImageIndex].name)
			return
		end
	end
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
	if currentVuImageKey == dicKey then
		-- image is the current one
		return currentVuImage, entry.vutype
	end
	if currentVuImage ~= nil then
		currentVuImage = nil
		currentVuImageKey = nil
	end
	if entry.vutype ~= "frame" then
		return getVFDVUmeter(entry.name, w, h), entry.vutype
	end
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
			if (allowCaching and selected) or CACHE_EAGER then
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
