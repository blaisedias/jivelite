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
	if srcW == w and h == srcH then
		log:debug("scaleSpectrumImage done", img)
		return img
	-- scale: whilst trying to maintain proportions
	-- if scaled width is > required clip the horizontal edges
	elseif scaledW == w then
		log:debug("scaleSpectrumImage simple resize")
		scaledImg = img:resize(w, h)
	elseif scaledW > w then
		local tmp = img:resize(scaledW, h)
		scaledImg = img:resize(w, h)
		log:debug("scaleSpectrumImage resize + hclip")
		-- upto 1 pixel smaller for odd numbered width differences
		tmp:blitClip(math.floor((scaledW-w)/2), 0, w, h, scaledImg, 0, 0)
		tmp:release()
	else
	-- if scaled width < than window width the expand - distorts proportion
	-- this is desired behaviour for vertically thin source images
	-- which typically would be colour gradients
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
		log:debug("readCacheDir: ", parts[1], " ", diskImageCache[parts[1]])
	end
end

-------------------------------------------------------- 
--- spectrum images
-------------------------------------------------------- 
local spImageIndex = 1
local spectrumImages = {}
local spectrumImagesMap = {}

function addSpectrumImage(tbl, path, w, h)
	log:debug("addSpectrumImage ",  path)
	local imgName = getImageName(path)
	local icKey = w .. "x" .. h .. "-" .. imgName
	local dcpath = diskImageCache[icKey]
	local bgIcKey = w .. "x" .. h .. "-" .. "BG-" .. imgName
	local bg_dcpath = cachedPath(bgIcKey)
	if dcpath == nil then
		local img = _scaleSpectrumImage(path, w, h)
		local fgimg = Surface:newRGB(w, h)
		fgimg:filledRectangle(0,0,w,h,0)
		img:blitAlpha(fgimg, 0, 0, 0)
		dcpath = cachedPath(icKey)
		-- imageCache[icKey] = img
		fgimg:saveBMP(dcpath)
		fgimg:release()
		if imgName:find("fg-",1,true) == 1 then
			local bgimg = Surface:newRGB(w, h)
			bgimg:filledRectangle(0,0,w,h,0)
			img:blitAlpha(bgimg, 0, 0, 0)
			bgimg:saveBMP(bg_dcpath)
			bgimg:release()
			imageCache[bgIcKey] = bg_dcpath
		end
		img:release()
	else
		log:debug("addSpectrumImage found cached ", dcpath)
		-- imageCache[icKey] = Surface:loadImage(dcpath)
	end
	imageCache[icKey] = dcpath
	if imgName:find("fg-",1,true) == 1 then
		imageCache[bgIcKey] = bg_dcpath
		table.insert(spectrumImages, {name=imgName, enabled=true})
		spectrumImagesMap[imgName] = {imgName, "BG-" .. imgName} 
	else
		table.insert(spectrumImages, {name=imgName, enabled=true})
		spectrumImagesMap[imgName] = {imgName, nil} 
	end
	log:debug("addSpectrumImage image cache Key: ", icKey)
end


local currentFgImage = nil
local currentFgImageKey = nil
function getFgSpectrumImage(tbl, w,h)
	log:debug("getFgImage: ", w, " ", h)
	local spkey = spectrumImages[spImageIndex].name
	if spectrumImagesMap[spkey][1] == nil then
		return nil
	end

	local icKey = w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey][1]
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey][1], " ", icKey)

	if currentFgImageKey == icKey then
		return currentFgImage
	end
	if currentFgImage ~= nil then
		log:debug("getFgImage: release currentFgImage ", currentFgImageKey)
		currentFgImage:release()
		currentFgImage = nil
		currentFgImageKey = nil
	end
	if imageCache[icKey] ~= nil then 
		log:debug("getFgImage: load ", icKey, " ", imageCache[icKey])
		currentFgImage = Surface:loadImage(imageCache[icKey])
		currentFgImageKey = icKey
	end
	return currentFgImage
end

local currentBgImage = nil
local currentBgImageKey = nil
function getBgSpectrumImage(tbl, w,h) 
	log:debug("getBgImage: ", w, " ", h)
	local spkey = spectrumImages[spImageIndex].name
	if spectrumImagesMap[spkey][2] == nil then
		return nil
	end

	local icKey = w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey][2]
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey][2], " ", icKey)
	if currentBgImageKey == icKey then
		return currentBgImage
	end
	if currentBgImage ~= nil then
		log:debug("getBgImage: release currentBgImage ", currentBgImageKey)
		currentBgImage:release()
		currentBgImage = nil
		currentBgImageKey = nil
	end
	if imageCache[icKey] ~= nil then 
		log:debug("getBgImage: load ", icKey, " ", imageCache[icKey])
		currentBgImage = Surface:loadImage(imageCache[icKey])
		currentBgImageKey = icKey
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
	local icKey = w .. "x" .. h .. "-" .. imgName
	local dcpath = diskImageCache[icKey]
	if dcpath == nil then
		local img = _scaleAnalogVuMeter(path, w, h, 25)
		dcpath = cachedPath(icKey)
		--imageCache[icKey] = img
		img:saveBMP(dcpath)
		img:release()
	else
		log:debug("addVuImage found cached ", dcpath)
		--imageCache[icKey] = Surface:loadImage(dcpath)
	end
	imageCache[icKey] = dcpath

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
	local icKey = w .. "x" .. h .. "-" .. vuImages[vuImageIndex].name
	if currentVuImageKey == icKey then
		return currentVuImage
	end
	if currentVuImage ~= nil then
		log:debug("getVuImage: release currentVuImage ", currentVuImageKey)
		currentVuImage:release()
		currentVuImage = nil
		currentVuImageKey = nil
	end
	if imageCache[icKey] ~= nil then 
		log:debug("getVuImage: load ", icKey, " ", imageCache[icKey])
		currentVuImage = Surface:loadImage(imageCache[icKey])
		currentVuImageKey = icKey
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

-- syncStatus is used to prevent unnecessary work
-- not a satisfactory solution - good enough for now.
-- Problem statement : The very first time NowPlaying
-- shows we need to sync settings, and thereafter when
-- settings are changed.
-- however in NowPlaying there is no convenient way to do
-- so without repeating the work frequently.
function getSyncStatus()
	return settingsSynced
end

function setSyncStatus()
	settingsSynced = true
end

function clearSyncStatus()
	settingsSynced = false
end

function sync()
	if not vuImages[vuImageIndex].enabled then
		vuBump()
	end
	if not spectrumImages[vuImageIndex].enabled then
		spBump()
	end
end

function isCurrentVUMeterEnabled()
	return vuImages[vuImageIndex].enabled
end

