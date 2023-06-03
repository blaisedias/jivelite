local oo            = require("loop.simple")
local math          = require("math")

local Framework     = require("jive.ui.Framework")
local Icon          = require("jive.ui.Icon")
local Surface       = require("jive.ui.Surface")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")

local vis           = require("jive.vis")
local visImage      = require("jive.visImage")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jivelite.vis")

local FRAME_RATE    = jive.ui.FRAME_RATE

local appletManager = appletManager

module(...)
oo.class(_M, Icon)

-- local imageCache = {}

function __init(self, style)
	local obj = oo.rawnew(self, Icon(style))

	obj.style = style

	obj.cap = { 0, 0 }

	obj:addAnimation(function() obj:reDraw() end, FRAME_RATE)

	return obj
end


function _skin(self)
	Icon._skin(self)

	if self.style == "vumeter" then
		self.bgImg = self:styleImage("bgImg")
		self.tickCap = self:styleImage("tickCap")
		self.tickOn = self:styleImage("tickOn")
		self.tickOff = self:styleImage("tickOff")

	elseif self.style == "vumeter_analog" then
--		self.srcBgImg = self:styleImage("bgImgPath")
		self.imgPath = self:styleImage("bgImgPath")
	end
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()
	self.src_y = 0

	self.player = appletManager:callService("getCurrentPlayer")

	-- When used in NP screen _layout gets called with strange values
--	BlaiseD disabling this check allows us to render VU Meters for newer
--	screen resolutions correctly
--	if (w <= 0 or w > 480) and (h <= 0 or h > 272) then
--		return
--	end

	-- When used in NP screen _layout gets called with strange values
	if (w <= 0) and (h <= 0) then
		return
	end

	if self.style == "vumeter" then
		self.w = w - l - r
		self.h = h - t - b

		local tw,th = self.tickOn:getMinSize()

		self.x1 = x + l + ((self.w - tw * 2) / 3)
		self.x2 = x + l + ((self.w - tw * 2) / 3) * 2 + tw

		self.bars = self.h / th
		self.y = y + t + (self.bars * th)

	elseif self.style == "vumeter_analog" then
    	log:debug("-----------------------------------------------------------------------")
        local xoffs = 0
        if w > 1280 then
    	    log:debug("** cutting", w)
            xoffs = (w - 1280)/2
            w = 1280
        end
		self.x1 = x + xoffs
		self.x2 = x + math.floor(w / 2) + xoffs
		self.y = y
		self.w = math.floor(w / 2)
		self.h = h
	    self.bgImg = _scaleAnalogVuMeter(visImage.getVuImage(), self.w * 2, h, 25)
	    local imgW, imgH = self.bgImg:getSize()
		-- center vertically
		if imgH < h then
			self.y = math.floor(self.y + ((h - imgH)/2))
		elseif imgH > h then
--			 self.src_y = math.floor((imgH - h)/2)
--			 the vast majority of VUMeter images have a ton of space above them,
--			 so render the bottom part
			self.src_y = math.floor(imgH - h)
		end
		log:debug("** x1:", self.x1, " x2:", self.x2, " y:", self.y, " src_y:", self.src_y)
		log:debug("** w:", self.w, " h:", self.h)
		log:debug("** bgImg-w:", imgW, " bgImg-h:", imgH)
	end
end


-- scale an image to fit a width
function _scaleAnalogVuMeter(imgPath, w, h, seq)
    local key = w .. "x" .. h .. "-" .. imgPath
    log:debug("_scaleAnalogVuMeter key:", key )
    local scaledImg =  visImage:cacheGet(key)
    if scaledImg then
        log:debug("got cached " .. key)
        return scaledImg
    end
    local img = Surface:loadImage(imgPath)
    log:debug("_scaleAnalogVuMeter loaded:", imgPath)
	local srcW, srcH = img:getSize()
    local wSeq = math.floor((w/2))*seq
	-- for VUMeter width determines the scaling factor
	local scaledH = math.floor(srcH * (wSeq/srcW))
    log:debug("_scaleAnalogVuMeter srcW:", srcW, " srcH:", srcH, " -> wSeq:", wSeq, " h:", h, " scaledH:", scaledH)
--    img:release()
--    visImage:cachePut(key, scaledImg)
--    return scaledImg
	-- after scaling:
	if scaledH > h then
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
	    scaledImg = img:resize(wSeq,scaledH)
    end
    img:release()
    visImage:cachePut(key, scaledImg)
    return scaledImg
end


function draw(self, surface)
	if self.style == "vumeter" then
		self.bgImg:blit(surface, self:getBounds())
	end

	local sampleAcc = vis:vumeter()

	-- local volume = self.player:getVolume()

	_drawMeter(self, surface, sampleAcc, 1, self.x1, self.y, self.w, self.h)
	_drawMeter(self, surface, sampleAcc, 2, self.x2, self.y, self.w, self.h)
end

-- FIXME dynamic based on number of bars
local RMS_MAP = {
	0, 2, 5, 7, 10, 21, 33, 45, 57, 82, 108, 133, 159, 200, 
	242, 284, 326, 387, 448, 509, 570, 652, 735, 817, 900, 
	1005, 1111, 1217, 1323, 1454, 1585, 1716, 1847, 2005, 
	2163, 2321, 2480, 2666, 2853, 3040, 3227, 3414, 3601,
	3788, 3975, 4162, 4349, 4536,
}

function _drawMeter(self, surface, sampleAcc, ch, x, y, w, h)
	local val = 1
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc[ch] > RMS_MAP[i] then
			val = i
			break
		end
	end

	-- FIXME when rms map scaled
	val = math.floor(val / 2)

--	val = math.floor(math.log(sampleAcc[ch]) * 1.5)
--	if val > 24 then
--		val = 24
--	end

	if val >= self.cap[ch] then
		self.cap[ch] = val
	elseif self.cap[ch] > 0 then
		self.cap[ch] = self.cap[ch] - 1
	end

	if self.style == "vumeter" then

		local tw,th = self.tickOn:getMinSize()

		for i = 1, self.bars do
			if i == math.floor(self.cap[ch] / 2) then
				self.tickCap:blit(surface, x, y, tw, th)
			elseif i < val then
				self.tickOn:blit(surface, x, y, tw, th)
			else
				self.tickOff:blit(surface, x, y, tw, th)
			end

			y = y - th
		end

	elseif self.style == "vumeter_analog" then

--		local x,y,w,h = self:getBounds()

		if ch == 1 then
			self.bgImg:blitClip(self.cap[ch] * w, self.src_y, w, h, surface, x, y)
		else
			self.bgImg:blitClip(self.cap[ch] * w, self.src_y, w, h, surface, x, y)
		end
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

