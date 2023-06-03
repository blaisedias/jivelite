local math          = require("math")
local Surface       = require("jive.ui.Surface")
local vis           = require("jive.vis")
local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jivelite.vis")

local ipairs,pairs  = ipairs,pairs

module(...)

local imageCache = {}

function scaleSpectrumImage(obj, imgPath, w, h)
    if imgPath == nil then
        return nil
    end
    local key = w .. "x" .. h .. "-" .. imgPath
    log:debug("scaleSpectrumImage imagePath:", imgPath, " w:", w, " h:", h, " key:", key)
    if imageCache[key] then
        log:debug("scaleSpectrumImage found cached image")
    else
        imageCache[key] = _scaleSpectrumImage(imgPath, w, h)
    end
    return imageCache[key]
end

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

function scaleAnalogVuMeter(obj, imgPath, w, h)
    if imgPath == nil then
        return nil
    end
    local key = w .. "x" .. h .. "-" .. imgPath
    log:debug("scaleAnalogVuMeter imagePath:", imgPath, " w:", w, " h:", h, " key:", key)
    if imageCache[key] then
        log:debug("scaleAnalogVuMeter found cached image")
    else
        imageCache[key] = _scaleAnalogVuMeter(imgPath, w, h)
    end
    return imageCache[key]
end

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


function cachePut(obj, key, img)
    imageCache[key] = img
end

function cacheGet(obj, key)
    if imageCache[key] then
        return imageCache[key]
    end
    return nil
end

function cacheClear(obj)
    log:debug("cacheClear ")
    for k,v in pairs(imageCache) do
        log:debug("cacheClear ", k)
        v:release()
        imageCache[k] = nil
    end
end

-------------------------------------------------------- 
--- spectrum images
-------------------------------------------------------- 
local spImageIndex = 1

local spectrumImages = {
    { "applets/JogglerSkin/images/UNOFFICIAL/Spectrum/gradient.png",
        "applets/JogglerSkin/images/bNOFFICIAL/Spectrum/background.png",
    },
    { "applets/JogglerSkin/images/UNOFFICIAL/Spectrum/gradient-1.png",
        nil,
    },
    { "applets/JogglerSkin/images/UNOFFICIAL/Spectrum/gradient-2.png",
        nil,
    },
    { "applets/JogglerSkin/images/UNOFFICIAL/Spectrum/gradient-c.png",
        nil,
    },
}


function getFgSpectrumImage()
    log:debug("--fg ", spImageIndex, ", ", spectrumImages[spImageIndex][0])
    return spectrumImages[spImageIndex][1]
end

function getBgSpectrumImage() 
    log:debug("--bg ", spImageIndex, ", ", spectrumImages[spImageIndex][1])
    return spectrumImages[spImageIndex][2]
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
    "applets/JogglerSkin/images/UNOFFICIAL/VUMeter/vu_analog_25seq_w.png",
    "applets/JogglerSkin/images/UNOFFICIAL/VUMeter/vu_analog_25seq_b.png",
}
local vuImageIndex = 1

function vuBump()
    log:debug("vuBump was ", vuImageIndex, " of ", #vuImages)
    vuImageIndex = (vuImageIndex % #vuImages) + 1
    log:debug("vuBump is ", vuImageIndex, " of ", #vuImages)
end

function getVuImage()
    log:debug("--vu ", vuImageIndex, ", ", vuImages[vuImageIndex])
    return vuImages[vuImageIndex]
end

function setVuImages(pathList) 
    vuImages = pathList
end

