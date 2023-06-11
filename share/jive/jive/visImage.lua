local math          = require("math")
local string        = require("jive.utils.string")
local Surface       = require("jive.ui.Surface")
local vis           = require("jive.vis")
local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jivelite.vis")
local System        = require("jive.System")

local ipairs, pairs, pcall  = ipairs, pairs, pcall
local lfs              = require("lfs")
local table = require("table")

local coroutine, package = coroutine, package
local lfs              = require("lfs")


module(...)

local imageCache = {}
local userdirpath = System.getUserDir()
local cachedir = userdirpath .. "/visucache"

function getImageName(imgPath)
	local fullpath = string.split("/", imgPath)
	local name = fullpath[#fullpath]
	local parts = string.split("%.", name)
	return parts[1]
end

function cachedPath(name)
	local file = cachedir .. "/" .. name .. ".bmp"
	return file
end

--function saveCachedImage(name, img)
--	if lfs.attributes(cachedir, "mode") == nil then
--		log:debug("Making directory: ", cachedir)
--		local created, err = lfs.mkdir(cachedir)
--		if not created then
--			error(string:format("error creating dir '%s' (%s)", cachedir, err))
--		end
--	end
--	local file = cachedir .. "/" .. name .. ".bmp"
--	log:debug("saveBMP: ", file)
--	-- FIXME use pcall here
--	img:saveBMP(file)
--	log:debug("saved BMP: ", file)
--	return file
--end

--function scaleSpectrumImage(tbl, imgPath, w, h)
--	if imgPath == nil then
--		return nil
--	end
--	local key = w .. "x" .. h .. "-" .. imgPath
--	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h, " key:", key)
--	if imageCache[key] then
--		log:debug("scaleSpectrumImage found cached image")
--	else
--		local scaledImg = _scaleSpectrumImage(imgPath, w, h)
--		imageCache[key] = scaledImg
--	end
--	return imageCache[key]
--end

-- scale an image to fit a height - maintaining aspect ration
function _scaleSpectrumImage(imgPath, w, h)
	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h)
	local img = Surface:loadImage(imgPath)
	log:debug("scaleSpectrumImage: got img")
	local scaledImg
	local srcW, srcH = img:getSize()
	log:debug("scaleSpectrumImage: srcW:", srcW, " srcH:", srcH)
	-- for spectrum height is determines the scaling factor
	local scaledW = math.floor(srcW * (h/srcH))
	log:debug("scaleSpectrumImage srcW:", srcW, " srcH:", srcH, " -> w:", w, " h:", h, " scaledW:", scaledW)
	if scaledW == w and h == srcH then
		log:debug("scaleSpectrumImage done", img)
		return img
	elseif srcW > w and srcH > h then
		log:debug("scaleSpectrumImage clip x-center y-bottom")
		scaledImg = img:resize(w, h)
		img:blitClip(math.floor((srcW-w)/2), srcH -h , w, h, scaledImg, 0, 0)
	-- after scaling:
	elseif scaledW < w then
	-- if width < than window width the expand - distorts proportion
	-- this is desired behaviour for vertically thin source images
	-- which typically would be colour gradients
		log:debug("scaleSpectrumImage simple resize")
		scaledImg = img:resize(w, h)
	else
	-- if width > then window width then clip the source image,
	-- this preserves proportion
		log:debug("scaleSpectrumImage resize and clip")
		local tmp = img:resize(scaledW, h)
		-- FIXME: find cheaper way to create an image of wxh
		scaledImg = img:resize(w,h)
		tmp:blitClip(math.floor((scaledW-w)/2), 0, scaledW-w, h, scaledImg, 0, 0)
		tmp:release()
	end
	img:release()
	log:debug("scaleSpectrumImage done")
	return scaledImg
end

--function scaleAnalogVuMeter(tbl, imgPath, w, h)
--	if imgPath == nil then
--		return nil
--	end
--	local key = w .. "x" .. h .. "-" .. imgPath
--	log:debug("scaleAnalogVuMeter imagePath:", imgPath, " w:", w, " h:", h, " key:", key)
--	if imageCache[key] then
--		log:debug("scaleAnalogVuMeter found cached image")
--	else
--		imageCache[key] = _scaleAnalogVuMeter(imgPath, w, h)
--	end
--	return imageCache[key]
--end

-- scale an image to fit a width - maintaining aspect ratio 
function _scaleAnalogVuMeter(imgPath, w, h, seq)
	log:debug("_scaleAnalogVuMeter imgPath:", imgPath )
	local img = Surface:loadImage(imgPath)
	log:debug("_scaleAnalogVuMeter loaded:", imgPath)
	local srcW, srcH = img:getSize()
	local wSeq = math.floor((w/2))*seq
	-- for VUMeter width determines the scaling factor
	local scaledH = math.floor(srcH * (wSeq/srcW))
	log:debug("_scaleAnalogVuMeter srcW:", srcW, " srcH:", srcH, " -> wSeq:", wSeq, " h:", h, " scaledH:", scaledH)
	if wSeq == srcW and h == srcH then
		return img
	-- after scaling:
	elseif scaledH > h then
	-- if height > then window height then clip the source image,
	-- this preserves proportion
		log:debug("_scaleAnalogVuMeter resize and clip")
		local tmp = img:resize(wSeq, scaledH)
		scaledImg = img:resize(wSeq,h)
		-- FIXME: should really clip top and bottom - however:
		-- stock images are kind of bottom justfied so clip the top of the image
		tmp:blitClip(0, math.floor(scaledH-h), wSeq, h, scaledImg, 0, 0)
		tmp:release()
	else
		scaledImg = img:resize(wSeq, scaledH)
	end
	img:release()
	return scaledImg
end


--function cachePut(tbl, key, img)
--	imageCache[key] = img
--end
--
--function cacheGet(tbl, key)
--	if imageCache[key] then
--		return imageCache[key]
--	end
--	return nil
--end

function cacheClear(tbl)
	log:debug("cacheClear ")
	for k,v in pairs(imageCache) do
		log:debug("cacheClear ", k)
--		v:release()
		imageCache[k] = nil
	end
end

local function dirIter(parent, rpath)
	local fq_path = parent .. "/" .. rpath
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		dir = dir .. rpath
		if dir == fq_path then
			local mode = lfs.attributes(dir, "mode")
		
			if mode == "directory" then
				for entry in lfs.dir(dir) do
					if entry ~= "." and entry ~= ".." and entry ~= ".svn" then
						coroutine.yield(entry)
					end
				end
			end
		end
	end
end

local function readdir(parent, rpath)
	local co = coroutine.create(function() dirIter(parent, rpath) end)
	return function()
		local code, res = coroutine.resume(co)
		return res
	end
end

local diskImageCache = {}

function readCacheDir()
	for img in readdir(userdirpath, "visucache") do
		local parts = string.split("%.", img)
		diskImageCache[parts[1]] = cachedir .. "/" .. img
		log:debug("#### ", parts[1], " ", diskImageCache[parts[1]])
	end
end

-------------------------------------------------------- 
--- spectrum images
-------------------------------------------------------- 
local spImageIndex = 1
--local spImagePaths = {}

function addSpectrumImage(tbl, path, w, h)
	log:debug("addSpectrumImage ",  path)
	local imgName = getImageName(path)
	local key = w .. "x" .. h .. "-" .. imgName
	dcpath = diskImageCache[key]
	if dcpath == nil then
		local cached_path = cachedPath(key)
		img = _scaleSpectrumImage(path, w, h)
		-- imageCache[key] = img
		img:saveBMP(cached_path)
        img:release()
	else
		log:debug("addSpectrumImage found cached ", dcpath)
		-- imageCache[key] = Surface:loadImage(dcpath)
	end
    imageCache[key] = dcpath
	log:debug("addSpectrumImage key: ", key)
--	table.insert(spImagePaths, path)
end

local spectrumImages = {
	{ "fg-8499490", "bg-8499490", },
	{ "fg-8499492", "bg-8499492", },
	{ "fg-8499494", "bg-8499494", },
	{ "fg-8499496", "bg-8499496", },
	{ "fg-spectrum-1", "bg-spectrum-1", },
	{ "fg-spectrum-2", "bg-spectrum-2", },
	{ "fg-spectrum-3", "bg-spectrum-3", },
	{ "fg-spectrum-4", "bg-spectrum-4", },
	{ "fg-spectrum-5", "bg-spectrum-5", },
	{ "fg-spectrum-6", "bg-spectrum-6", },
	{ "fg-spectrum-7", "bg-spectrum-7", },
--	{ "gradient", "background", },
--	{ "gradient-1", nil, },
--	{ "gradient-2", nil,},
--	{ "gradient-c", nil, },
}


local currentFgImage = nil
local currentFgImageKey = nil
function getFgSpectrumImage(tbl, w,h)
	local key = w .. "x" .. h .. "-" ..  spectrumImages[spImageIndex][1]
	log:debug("--fg ", spImageIndex, ", ", spectrumImages[spImageIndex][1], " ", key)
    if currentFgImageKey == key then
        return currentFgImage
    end
    if currentFgImage ~= nil then
        log:debug("getFgImage: release currentFgImage ", currentFgImageKey)
        currentFgImage:release()
        currentFgImage = nil
        currentFgImageKey = nil
    end
    if imageCache[key] ~= nil then 
        log:debug("getFgImage: load ", key, " ", imageCache[key])
        currentFgImage = Surface:loadImage(imageCache[key])
        currentFgImageKey = key
    end
	return currentFgImage
end

local currentBgImage = nil
local currentBgImageKey = nil
function getBgSpectrumImage(tbl, w,h) 
	log:debug("--bg ", w, " ", h)
	local key = w .. "x" .. h .. "-" ..  spectrumImages[spImageIndex][2]
	log:debug("--bg ", spImageIndex, ", ", spectrumImages[spImageIndex][2], " ", key)
    if currentBgImageKey == key then
        return currentBgImage
    end
    if currentBgImage ~= nil then
        log:debug("getBgImage: release currentBgImage ", currentBgImageKey)
        currentBgImage:release()
        currentBgImage = nil
        currentBgImageKey = nil
    end
    if imageCache[key] ~= nil then 
        log:debug("getBgImage: load ", key, " ", imageCache[key])
        currentBgImage = Surface:loadImage(imageCache[key])
        currentBgImageKey = key
    end
	return currentBgImage
end

function spBump()
	log:debug("spBump was ", spImageIndex, " of ", #spectrumImages)
	spImageIndex = (spImageIndex % #spectrumImages) + 1
	log:debug("spBump is ", spImageIndex, " of ", #spectrumImages)
end

function setSpectrumImages(pathList)
	sectrumImages = pathList
	spImageIndex = 1
end

-------------------------------------------------------- 
--- VU meter images
-------------------------------------------------------- 
local vuImages = {
}
local vuImageIndex = 1
local vuBumpValue = 1

function addVuImage(tbl, path, w, h)
	log:debug("addVuImage ",  path)
	local imgName = getImageName(path)
	local key = w .. "x" .. h .. "-" .. imgName
	dcpath = diskImageCache[key]
	if dcpath == nil then
		local cached_path = cachedPath(key)
		local img = _scaleAnalogVuMeter(path, w, h, 25)
		--imageCache[key] = img
		img:saveBMP(cached_path)
        img:release()
	else
		log:debug("addVuImage found cached ", dcpath)
		--imageCache[key] = Surface:loadImage(dcpath)
	end
    imageCache[key] = dcpath

	for k,v in pairs(vuImages) do
		if v.name == imgName then
			return
		end
	end
	table.insert(vuImages, {name=imgName, enabled=false})
end

function vuBump()
	for i = 1, #vuImages do
		vuImageIndex = (vuImageIndex % #vuImages) + vuBumpValue
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
	local key = w .. "x" .. h .. "-" .. vuImages[vuImageIndex].name
    if currentVuImageKey == key then
        return currentVuImage
    end
    if currentVuImage ~= nil then
        log:debug("getVuImage: release currentVuImage ", currentVuImageKey)
        currentVuImage:release()
        currentVuImage = nil
        currentVuImageKey = nil
    end
    if imageCache[key] ~= nil then 
        log:debug("getVuImage: load ", key, " ", imageCache[key])
        currentVuImage = Surface:loadImage(imageCache[key])
        currentVuImageKey = key
    end
	return currentVuImage
end

function getVUImageList()
	return vuImages
end

function selectVuImage(tbl, name, selected)
	n_enabled = 0
	log:debug("selectVuImage", " ", name, " ", selected)
	for k, v in pairs(vuImages) do
		if v.name == name then
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectVuImage", " enabled count: ", n_enabled)
	return n_enabled
end

local settingsSynced = false

function getSyncStatus()
	return settingsSynced
end

function setSyncStatus()
	settingsSynced = true
end

function isCurrentVUMeterEnabled()
	return vuImages[vuImageIndex].enabled
end

