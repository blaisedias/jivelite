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


function __init(self, style)
	local obj = oo.rawnew(self, Icon(style))

	obj.style = style

	obj.cap = { 0, 0 }

	obj.ix = { 0, 0 }

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
		self.bgImg = self:styleImage("bgImg")
		if self.bgImg then
			self.legacy = true
		else
			self.legacy = false
		end
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
		if self.legacy then
			self.x1 = x
			self.x2 = x + (w / 2)
			self.y = y
			self.w = w / 2
			self.h = h
		else
			log:debug("-----------------------------------------------------------------------")
			self.y = y
			self.w = math.floor(w / 2)
			self.h = h
			self.vutbl, self.vutype = visImage.getVuImage(w,h)
   			if self.vutype == "frame"  then
				self.bgImg = self.vutbl
				if self.bgImg ~= nil then
					local imgW, imgH = self.bgImg:getSize()
					-- FIXME VU Meter images will not always be 25 frames
					self.frame_w = imgW/25
					-- centre the VUMeter image within the designated space
					-- horizontally
					self.x1 = x + self.w - self.frame_w
					self.x2 = self.x1 + self.frame_w
					-- vertically
					if imgH < h then
						self.y = math.floor(self.y + ((h - imgH)/2))
					elseif imgH > h then
						-- clip the image at the top and bottom
						self.src_y = math.floor((imgH - h)/2)
					end
					log:debug("** x1:", self.x1, " x2:", self.x2, " y:", self.y, " src_y:", self.src_y)
					log:debug("** w:", self.w, " frame_w:", self.frame_w, " h:", self.h)
					log:debug("** bgImg-w:", imgW, " bgImg-h:", imgH)
				end
            elseif self.vutype == "vfd" then
				self.vfd = self.vutbl
				self.x1 = x + math.floor((w - self.vfd.w)/2)
				self.x2 = self.x1
--				log:debug("******* vfd x=", self.x1)
				local y1 = self.y + math.floor((h - self.vfd.h)/2)
--				log:debug("******* vfd y1=", y1)
				self.vfd.cy = y1 + self.vfd.bh
				local y2 = self.vfd.cy + self.vfd.ch
--				log:debug("******* vfd y2=", y2)
				self.vfd.y = {y1, y2}
				self.vfd.cap = {-1, -1}
				self.vfd.peak_hold_counter = {0, 0}
--				log:debug("******* vfd y1=", y1, " cy=", self.vfd.cy, " y2=", y2)
			end
		end
	end
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
	   0,    2,    5,    7,   10,   21,   33,   45,   57,   82,
	 108,  133,  159,  200,  242,  284,  326,  387,  448,  509,
	 570,  652,  735,  817,  900, 1005, 1111, 1217, 1323, 1454,
	1585, 1716, 1847, 2005, 2163, 2321, 2480, 2666, 2853, 3040,
	3227, 3414, 3601, 3788, 3975, 4162, 4349, 4536, 4755,
}

function _drawMeter(self, surface, sampleAcc, ch, x, y, w, h)
	local val = 1
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc[ch] > RMS_MAP[i] then
			val = i
			break
		end
	end

	local dvval = val
	-- FIXME when rms map scaled
	val = math.floor((val % 49)/2)

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

		if self.vutype == "frame" then
			-- smoother transitions => the loss of accuracy
			-- frame change speed is exponential derived from difference
			-- like real VU meters
			-- local delta = math.floor((self.cap[ch] - self.ix[ch])/2)
			-- self.ix[ch] = self.ix[ch] + delta
			if self.bgImg ~= nil then
				-- self.bgImg:blitClip(self.ix[ch] * self.frame_w, self.src_y, self.frame_w, h, surface, x, y)
				self.bgImg:blitClip(self.cap[ch] * self.frame_w, self.src_y, self.frame_w, h, surface, x, y)
			end
		else
			if dvval > 1 and dvval >= self.vfd.cap[ch] then
				self.vfd.cap[ch] = dvval
				self.vfd.peak_hold_counter[ch] = math.floor(FRAME_RATE/2)
			else
				self.vfd.peak_hold_counter[ch] = self.vfd.peak_hold_counter[ch] - 1
				if self.vfd.peak_hold_counter[ch] < 1 then
					self.vfd.cap[ch] = -1
				end
			end

			local dvx = x
			local dvy = self.vfd.y[ch]
			self.vfd.blead[ch]:blit(surface, dvx, dvy, self.vfd.lw, self.vfd.lh)
			dvx = dvx + self.vfd.lw
			for i = 1, 36 do
				if i < dvval or i == self.vfd.cap[ch] then
					self.vfd.on:blit(surface, dvx, dvy, self.vfd.bw, self.vfd.bh)
				else
					self.vfd.off:blit(surface, dvx, dvy, self.vfd.bw, self.vfd.bh)
				end
				dvx = dvx + self.vfd.bw
			end
			for i = 37, 49 do
				if i < dvval or i == self.vfd.cap[ch] then
					self.vfd.peakon:blit(surface, dvx, dvy, self.vfd.bw, self.vfd.h)
				else
					self.vfd.peakoff:blit(surface, dvx, dvy, self.vfd.bw, self.vfd.h)
				end
				dvx = dvx + self.vfd.bw
			end

			if self.vfd.center ~= nil then
				self.vfd.center:blit(surface, x, self.vfd.cy, self.vfd.cw, self.vfd.ch)
			end

		end
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

