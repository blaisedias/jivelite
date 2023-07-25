-- lua package imports
local math          = require("math")
local table         = require("table")
local lfs           = require("lfs")

local ipairs, pairs, pcall  = ipairs, pairs, pcall
local coroutine, package    = coroutine, package

-- jive package imports
local string        = require("jive.utils.string")
local Surface       = require("jive.ui.Surface")
local vis           = require("jive.vis")
local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jivelite.vis")
local System        = require("jive.System")

module(...)

-------------------------------------------------------- 
--- disk image cache 
-------------------------------------------------------- 

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

function cacheClear(tbl)
	log:debug("cacheClear ")
	for k,v in pairs(imageCache) do
		log:debug("cacheClear ", k)
--		v:release()
		imageCache[k] = nil
	end
end

local function dirIter(rpath)
--	local fq_path = parent .. "/" .. rpath
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		dir = dir .. rpath
--		if dir == fq_path then
			local mode = lfs.attributes(dir, "mode")
		
			if mode == "directory" then
				for entry in lfs.dir(dir) do
					if entry ~= "." and entry ~= ".." and entry ~= ".svn" then
						coroutine.yield(entry, dir)
					end
				end
			end
--		end
	end
end

local function readdir(parent, rpath)
	local co = coroutine.create(function() dirIter(rpath) end)
	return function()
		local code, res, path = coroutine.resume(co)
		return res, path
	end
end


function readCacheDir()
--	for img, path in readdir(userdirpath, "visucache") do
	for img, path in readdir(nil, "primed-visu-images") do
		local parts = string.split("%.", img)
		if parts[2] == 'png' or parts[2] == 'jpg' or parts[2] == 'bmp' then
			imageCache[parts[1]] = path .. "/" .. img
			log:debug("readCacheDir: ", parts[1], " ", imageCache[parts[1]])
		end
	end
	for img, path in readdir(nil, "visucache") do
		local parts = string.split("%.", img)
		if parts[2] == 'png' or parts[2] == 'jpg' or parts[2] == 'bmp' then
			imageCache[parts[1]] = path .. "/" .. img
			log:debug("readCacheDir: ", parts[1], " ", imageCache[parts[1]])
		end
	end
end


-------------------------------------------------------- 
--- image scaling 
-------------------------------------------------------- 
-- scale an image to fit a height - maintaining aspect ration
function _scaleSpectrumImage(imgPath, w, h)
	log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h)
	-- FIXME: loads a "tile" which is not freed by release call
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
	-- if scaled width is > required clip the horizontal edges
	elseif scaledW > w then
		local tmp = img:resize(scaledW, h)
		scaledImg = img:resize(w, h)
		log:debug("scaleSpectrumImage resize + hclip")
		-- upto 1 pixel smaller for odd numbered width differences
		tmp:blitClip(math.floor((scaledW-w)/2), 0, w, h, scaledImg, 0, 0)
		tmp:release()
	elseif srcW > w and srcH > h then
	-- if src image is larger just clip
		log:debug("scaleSpectrumImage clip x-center y-bottom")
		scaledImg = img:resize(w, h)
		img:blitClip(math.floor((srcW-w)/2), srcH-h , w, h, scaledImg, 0, 0)
	elseif srcH > h and scaledW > (w/2) then
	-- if src image is almost larger enough expand to fill horizontally
	-- and clip vertically
		log:debug("scaleSpectrumImage expand to w, clip y-center")
		local scaledH = math.floor(srcH * (w/srcW))
		local tmp = img:resize(w, scaledH)
		scaledImg = img:resize(w, h)
		tmp:blitClip(0, (scaledH-h)/2, w, h, scaledImg, 0, 0)
		tmp:release()
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
	log:debug("scaleSpectrumImage done")
	return scaledImg
end

-- scale an image to fit a width - maintaining aspect ratio 
function _scaleAnalogVuMeter(imgPath, w_in, h, seq)
	local w = w_in
	log:debug("_scaleAnalogVuMeter imgPath:", imgPath )
	-- FIXME hack for screenwidth > 1280 
	-- resizing too large segfaults so VUMeter resize is capped at 1280
	if w > 1280 then
		log:debug("_scaleAnalogVuMeter !!!!! w > 1280 reducing to 1280 !!!!! ", imgPath )
		w = 1280
	end
	-- FIXME: loads a "tile" which is not freed by release call
	local img = Surface:loadImage(imgPath)
	log:debug("_scaleAnalogVuMeter loaded:", imgPath)
	local srcW, srcH = img:getSize()
	local wSeq = math.floor((w/2))*seq
	-- try scaling to fit width
	local scaledH = math.floor(srcH * (wSeq/srcW))
	log:debug("_scaleAnalogVuMeter srcW:", srcW, " srcH:", srcH, " -> wSeq:", wSeq, " h:", h, " scaledH:", scaledH)
	if wSeq == srcW and h == srcH then
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
	return scaledImg
end


-------------------------------------------------------- 
--- Spectrum 
-------------------------------------------------------- 
local spectrumList = {}
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
	table.insert(spectrumList, {name="default", enabled=false})
	spectrumImagesMap["default"] = {fg=nil, bg=nil, src=nil} 
end

function _cacheSpectrumImage(imgName, path, w, h)
	log:debug("_cacheSpectrumImage ", imgName, ", ", path, ", ", w, ", ", h)
	local bgImgName = nil
	local icKey = "for-" .. w .. "x" .. h .. "-" .. imgName
	local dcpath = imageCache[icKey]
	local bgIcKey = nil
	local bg_dcpath = nil

	-- for images starting with 'fg-' we synthesize the backgorund
	-- image from the foreground image, and render the foreground
	-- on top of the background image
	-- all other images are considered as foreground images rendered
	-- against a black background
	if imgName:find("fg-",1,true) == 1 then
		local l = imgName:len()
		local baseImgName = string.sub(imgName,4,l)
		bgImgName = "bg-" .. baseImgName
		bgIcKey = "for-" .. w .. "x" .. h .. "-" .. bgImgName
		bg_dcpath = cachedPath(bgIcKey)
	end
	if dcpath == nil then
		local img = _scaleSpectrumImage(path, w, h)
		local fgimg = Surface:newRGB(w, h)
		img:blit(fgimg, 0, 0, 0)
		dcpath = cachedPath(icKey)
		-- imageCache[icKey] = img
		fgimg:saveBMP(dcpath)
		fgimg:release()
		-- the fg and bg images appear identical right down to checksums
		-- however when rendering if bg and fg are the loaded from same
		-- the source contrast is lost :-(
		-- For now duplicate the images.
		-- It is possible that some lower level caching is 
		-- means that loading the same image twice does not yield
	 	-- 2 instances of the same image.
		-- TODO: figure out if how to use a single image source for both
		-- foreground and background retaining the contrast
		if imgName:find("fg-",1,true) == 1 then
--			local bgimg = Surface:newRGB(w, h)
--			bgimg:filledRectangle(0,0,w,h,0)
--			img:blitAlpha(bgimg, 0, 0, 80)
--			bgimg:saveBMP(bg_dcpath)
--			bgimg:release()
			local cwd = lfs.currentdir()
			lfs.chdir(cachedir)
			lfs.link(icKey .. ".bmp", bgIcKey .. ".bmp", true)
			lfs.chdir(cwd)
			imageCache[bgIcKey] = bg_dcpath
			log:debug("_cacheSpectrumImage cached ", bgIcKey)
		end
		img:release()
		imageCache[icKey] = dcpath
		log:debug("_cacheSpectrumImage cached ", icKey)
	else
		log:debug("_cacheSpectrumImage found cached ", dcpath)
		-- imageCache[icKey] = Surface:loadImage(dcpath)
		-- assume that the background image if any is also
		-- present in the disk image cache.
	end
end

function registerSpectrumImage(tbl, path, w, h)
	log:debug("registerSpectrumImage ",  path)
	local imgName = getImageName(path)

--	_cacheSpectrumImage(imgName, path, w, h)
	local bgImgName = nil
	if imgName:find("fg-",1,true) == 1 then
		local l = imgName:len()
		local baseImgName = string.sub(imgName,4,l)
		bgImgName = "bg-" .. baseImgName
	end

	if spectrumImagesMap[imgName] == nil then
		table.insert(spectrumList, {name=imgName, enabled=false})
	end
	spectrumImagesMap[imgName] = {fg=imgName, bg=bgImgName, src=path} 
end

function spBump()
	for i = 1, #spectrumList do
		spImageIndex = (spImageIndex % #spectrumList) + 1
		if spectrumList[spImageIndex].enabled == true then
			log:debug("spBump is ", spImageIndex, " of ", #spectrumList, ", ", spectrumList[spImageIndex].name)
			return
		end
	end
end

local currentFgImage = nil
local currentFgImageKey = nil
function getFgSpectrumImage(tbl, w,h)
	log:debug("getFgImage: ", w, " ", h)
	if not spectrumList[spImageIndex].enabled then
		spBump()
	end
	local spkey = spectrumList[spImageIndex].name
	if spectrumImagesMap[spkey].fg == nil then
		return nil
	end

	local icKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].fg
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg, " ", icKey)

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
		-- FIXME: loads a "tile" which is not freed by release call
		currentFgImage = Surface:loadImage(imageCache[icKey])
		currentFgImageKey = icKey
	else
		-- this is required to create cached images when skin change, changes the resolution.
		if spectrumImagesMap[spkey].src ~= nil then
			_cacheSpectrumImage(spkey, spectrumImagesMap[spkey].src, w, h)
			if imageCache[icKey] == nil then 
				spectrumImagesMap[spkey].src = nil
				return nil
			end
			-- FIXME: loads a "tile" which is not freed by release call
			currentFgImage = Surface:loadImage(imageCache[icKey])
			currentFgImageKey = icKey
		end
	end
	return currentFgImage
end

local currentBgImage = nil
local currentBgImageKey = nil
function getBgSpectrumImage(tbl, w,h) 
	log:debug("getBgImage: ", w, " ", h)
	if not spectrumList[spImageIndex].enabled then
		spBump()
	end
	local spkey = spectrumList[spImageIndex].name
	if spectrumImagesMap[spkey].bg == nil then
		return nil
	end

	local icKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].bg
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg, " ", icKey)
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
		currentBgImage = Surface:newRGB(w,h)
		currentBgImage:filledRectangle(0,0,w,h,0)
		-- FIXME: loads a "tile" which is not freed by release call
		local img = Surface:loadImage(imageCache[icKey])
		img:blitAlpha(currentBgImage, 0, 0, getBackgroundAlpha())
		img:blit(currentBgImage, 0, 0)
		img:release()
		currentBgImageKey = icKey
	else
		-- this is required to create cached images when skin change, changes the resolution.
		if spectrumImagesMap[spkey].src ~= nil then
			_cacheSpectrumImage(spkey, spectrumImagesMap[spkey].src, w, h)
			if imageCache[icKey] == nil then 
				spectrumImagesMap[spkey].src = nil
				return nil
			end
			-- FIXME: loads a "tile" which is not freed by release call
			currentBgImage = Surface:loadImage(imageCache[icKey])
			currentBgImageKey = icKey
		end
	end
	return currentBgImage
end

function selectSpectrum(tbl, name, selected)
	n_enabled = 0
	log:debug("selectSpectrum", " ", name, " ", selected)
	for k, v in pairs(spectrumList) do
		if v.name == name then
			if not v.enabled and selected then
				-- create the cached image for skin resolutions 
				for k, v in pairs(spectrumResolutions) do
					if spectrumImagesMap[name].src ~= nil then
						_cacheSpectrumImage(name, spectrumImagesMap[name].src, v.w, v.h)
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
	{name="skin"},
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
	{name="1-5-1-2", values={barsInBin=1, barWidth=5, barSpace=1, binSpace=2}},
	{name="2-2-1-2", values={barsInBin=2, barWidth=2, barSpace=1, binSpace=2}},
	{name="1-4-1-2", values={barsInBin=1, barWidth=4, barSpace=1, binSpace=2}},
	{name="1-3-1-3", values={barsInBin=1, barWidth=3, barSpace=1, binSpace=3}},
	{name="2-1-1-2", values={barsInBin=2, barWidth=1, barSpace=1, binSpace=2}},
	{name="1-2-1-2", values={barsInBin=1, barWidth=2, barSpace=1, binSpace=2}},
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
--- VU meter
-------------------------------------------------------- 
local vuImages = {
}
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
	local icKey = "for-" .. w .. "x" .. h .. "-" .. imgName
	local dcpath = imageCache[icKey]
	if dcpath == nil then
		local img = _scaleAnalogVuMeter(path, w, h, 25)
		dcpath = cachedPath(icKey)
		--imageCache[icKey] = img
		img:saveBMP(dcpath)
		img:release()
		imageCache[icKey] = dcpath
	else
		log:debug("_cacheVuImage found cached ", dcpath)
		--imageCache[icKey] = Surface:loadImage(dcpath)
	end
end

function registerVUMeterImage(tbl, path)
	log:debug("registerVUMeterImage ",  path)
	local imgName = getImageName(path)
	for k,v in pairs(vuImages) do
		if v.name == imgName then
			return
		end
	end
	local displayName = imgName
	local ixSub = string.find(imgName, "25seq")
	if ixSub ~= nil then
		if string.find(imgName, "25seq_") ~= nil or string.find(imgName, "25seq-") ~= nil then
			displayName = string.sub(imgName, ixSub + 6)
		else
			displayName = string.sub(imgName, ixSub + 5)
		end
	end
	table.insert(vuImages, {name=imgName, enabled=false, displayName=displayName, vutype="frame"})
	vuImagesMap[imgName] = {src=path}
end

function initVuMeterList()
	local dvudir = lfs.currentdir() .. "/assets/visualisers/vumeters/vfd"
	for entry in lfs.dir(dvudir) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(dvudir .. "/" .. entry, "mode")
			if mode == "directory" then
				path = dvudir .. "/" .. entry
				for f in lfs.dir(path) do
					mode = lfs.attributes(path .. "/" .. f, "mode")
					if mode == "file" then
						local parts = string.split("%.", f)
						if parts[2] == 'png' or parts[2] == 'jpg' or parts[2] == 'bmp' then
							log:debug("VFD ", entry .. ":" .. parts[1], "  ", path .. "/" .. f)
							imageCache[entry .. ":" .. parts[1]] = path .. "/" .. f
						end
					end
				end
				table.insert(vuImages, {name=entry, enabled=false, displayName=entry, vutype="vfd"})
			end
		end
	end
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
	local icKey = "for-" .. w .. "x" .. h .. "-" .. entry.name
	if currentVuImageKey == icKey then
		-- image is the current one
		return currentVuImage, entry.vutype
	end
	if currentVuImage ~= nil then
		-- release the current image
		log:debug("getVuImage: release currentVuImage ", currentVuImageKey)
		currentVuImage:release()
		currentVuImage = nil
		currentVuImageKey = nil
	end
	if entry.vutype ~= "frame" then
		return getVFDVUmeter(entry.name, w, h), entry.vutype
	end
	if imageCache[icKey] ~= nil then 
		-- image is in the cache load and return
		log:debug("getVuImage: load ", icKey, " ", imageCache[icKey])
		-- FIXME: loads a "tile" which is not freed by release call
		currentVuImage = Surface:loadImage(imageCache[icKey])
		currentVuImageKey = icKey
	else
		-- this is required to create cached images when skin change, changes the resolution.
		if vuImagesMap[entry.name].src ~= nil then
			log:debug("getVuImage: creating image for ", icKey)
			_cacheVUImage(entry.name, vuImagesMap[entry.name].src, w, h)
			if imageCache[icKey] == nil then
				-- didn't work zap the src string so we don't do this repeatedly
				log:debug("getVuImage: failed to create image for ", icKey)
				vumImagesMap[entry.name].src = nil
			end
			log:debug("getVuImage: load (new) ", icKey, " ", imageCache[icKey])
			-- FIXME: loads a "tile" which is not freed by release call
			currentVuImage = Surface:loadImage(imageCache[icKey])
			currentVuImageKey = icKey
		else
			log:debug("getVuImage: no image for ", icKey)
		end
	end
	return currentVuImage, entry.vutype
end


function selectVuImage(tbl, name, selected)
	n_enabled = 0
	log:debug("selectVuImage", " ", name, " ", selected)
	for k, v in pairs(vuImages) do
		if v.name == name then
			if not v.enabled and selected then
				if v.vutype == "frame" then
					-- create the cached image for skin resolutions 
					for k, v in pairs(vuMeterResolutions) do
						_cacheVUImage(name, vuImagesMap[name].src, v.w, v.h)
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

function getVFDVUmeter(name, w, h)
	local bar_on = name .. ":bar-on"
	local bar_off = name .. ":bar-off"
	local bar_peak_on = name .. ":bar-peak-on"
	local bar_peak_off = name .. ":bar-peak-off"
	local left = name .. ":left"
	local right = name .. ":right"
	local center = name .. ":center"
	vfd = {}
	local bw, bh = Surface:loadImage(imageCache[bar_on]):getSize()
   	local lw, lh = Surface:loadImage(imageCache[left]):getSize()
   	local cw, ch = Surface:loadImage(imageCache[center]):getSize()
	local dw = cw
	local dh = ch + (bh * 2)
--	log:debug("#### dw:", dw, " dh:", dh, " w:", w, " h:", h)
--	log:debug("#### ",lw, ",", lh, "  ", bw, ",", bh, "  ", cw, "," , ch)
	if w >= dw and h >= dh then
		vfd.on = Surface:loadImage(imageCache[bar_on])
		vfd.off = Surface:loadImage(imageCache[bar_off])
		vfd.peakon = Surface:loadImage(imageCache[bar_peak_on])
		vfd.peakoff = Surface:loadImage(imageCache[bar_peak_off])
		vfd.blead = { Surface:loadImage(imageCache[left]), Surface:loadImage(imageCache[right]) }
		vfd.center = Surface:loadImage(imageCache[center])
		vfd.w = dw
		vfd.h = dh
	else
		local sf = math.min(w/dw, h/dh)
		bw = math.floor(bw * sf)
		bh = math.floor(bh * sf)
		lw = math.floor(lw * sf)
		lh = math.floor(lh * sf)
		-- doh. Due to rounding differences,  scaling the calibration part like so
		-- cw = math.floor((cw*w)/dw)
		-- scales at odds with the smaller bits.
		cw = math.floor((bw *49) + (lw *2))
		ch = math.floor((ch * sf))
		vfd.on = Surface:loadImage(imageCache[bar_on]):resize(bw, bh)
		vfd.off = Surface:loadImage(imageCache[bar_off]):resize(bw, bh)
		vfd.peakon = Surface:loadImage(imageCache[bar_peak_on]):resize(bw, bh)
		vfd.peakoff = Surface:loadImage(imageCache[bar_peak_off]):resize(bw, bh)
		vfd.blead = { Surface:loadImage(imageCache[left]):resize(lw, lh), Surface:loadImage(imageCache[right]):resize(lw, lh) }
		vfd.center = Surface:loadImage(imageCache[center]):resize(cw, ch)
		vfd.w = cw
		vfd.h = ch + (bh * 2)
	end
	vfd.bw = bw
	vfd.bh = bh
	vfd.lw = lw
	vfd.lh = lh
	vfd.cw = cw
	vfd.ch = ch
--	log:debug("####  vfd.w:", vfd.w, " vfd.h:", vfd.h)
--	log:debug("####  vfd.bw:", vfd.bw, " vfd.bh:", vfd.bh, " vfd.lw:", vfd.lw, " vfd.lh", vfd.lh, " vfd.cw:", vfd.cw, " vfd.ch", vfd.ch)
	return vfd
end

------------------------------------------------------- 
--- Misc
-------------------------------------------------------- 
function registerComplete()
	table.sort(vuImages, function (left, right) return left.name < right.name end)
	table.sort(spectrumList, function (left, right) return left.name < right.name end)
end

function sync()
	if not vuImages[vuImageIndex].enabled then
		vuBump()
	end
	if not spectrumList[spImageIndex].enabled then
		spBump()
	end
end
