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
					local frame_w = imgW/25
					-- centre the VUMeter image within the designated space
					-- horizontally
					local fx= x + math.floor(w / 2) - frame_w
					-- vertically
					local fy = y
					local src_y = 0
					if imgH < h then
						fy = math.floor(self.y + ((h - imgH)/2))
					elseif imgH > h then
						-- clip the image at the top and bottom
						src_y = math.floor((imgH - h)/2)
					end
					self.left =  { img=self.bgImg, x=fx ,                   y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
					self.right = { img=self.bgImg, x=self.left.x + frame_w, y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
					log:debug("left : x:", self.left.x, " y:", self.left.y, " src_y:", self.left.src_y, " w:", self.left.w, " h:", self.left.h)
					log:debug("right: x:", self.right.x, " y:", self.right.y, " src_y:", self.right.src_y, " w:", self.right.w, " h:", self.right.h)
					self.drawMeter = draw25FrameVuMeter
				else
					self.left =  { img=bgImg }
					self.right = { img=bgImg }
				    self.drawMeter = nullDraw
				end
			elseif self.vutype == "vfd" then
				self.vfd = self.vutbl
				local vfdx = x + math.floor((w - self.vfd.w)/2)
				local y1 = self.y + math.floor((h - self.vfd.h)/2)
				local y2 = y1 + self.vfd.bh + self.vfd.ch
				self.left =  {x=(vfdx + self.vfd.lw), y=y1, cap=0, peak_hold_counter=0, vfd=self.vfd}
				self.right = {x=(vfdx + self.vfd.lw), y=y2, cap=0, peak_hold_counter=0, vfd=self.vfd}
				self.drawMeter = drawVFD

				self.bgParams = {x=vfdx, y=y1 + self.vfd.bh, vfd=self.vfd, left=self.left, right=self.right}
				self.drawBackground = drawVFDStatic
			end
		end
	end
end

-- FIXME dynamic based on number of bars
local RMS_MAP = {
	   0,    2,    5,    7,   10,   21,   33,   45,   57,   82,
	 108,  133,  159,  200,  242,  284,  326,  387,  448,  509,
	 570,  652,  735,  817,  900, 1005, 1111, 1217, 1323, 1454,
	1585, 1716, 1847, 2005, 2163, 2321, 2480, 2666, 2853, 3040,
	3227, 3414, 3601, 3788, 3975, 4162, 4349, 4536, 4755,
}

function samplAcc2Vol(sampleAcc)
	for i = #RMS_MAP, 1, -1 do
 		if sampleAcc > RMS_MAP[i] then
 			return i
  		end
   	end
	return 1
end

function draw(self, surface)
	if self.style == "vumeter" then
		self.bgImg:blit(surface, self:getBounds())
	end

	if self.bgParams ~= nil then
		self.drawBackground(self.bgParams, surface)
	end

	local sampleAcc = vis:vumeter()
	local vol = {samplAcc2Vol(sampleAcc[1]), samplAcc2Vol(sampleAcc[2])}

	-- local volume = self.player:getVolume()

	if self.drawMeter == nil then
		_drawMeter(self, surface, vol[1], 1, self.x1, self.y, self.w, self.h)
		_drawMeter(self, surface, vol[2], 2, self.x2, self.y, self.w, self.h)
	else
		self.drawMeter(self.left, surface, vol[1]) 
		self.drawMeter(self.right, surface, vol[1]) 
	end
end

function _drawMeter(self, surface, vol, ch, x, y, w, h, ptr)
	-- FIXME when rms map scaled
	local val = math.min(math.floor(vol/2), 24)

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

		self.bgImg:blitClip(self.cap[ch] * self.w, y, self.frame_w, h, surface, x, y)
	end
end

function drawVFD(self, surface, vol)
	local x = self.x
	local y = self.y
	if vol >= self.cap then
		self.cap = vol
		self.peak_hold_counter = math.floor(FRAME_RATE/2)
	else
		self.peak_hold_counter = self.peak_hold_counter - 1
		if self.peak_hold_counter < 1 then
			self.cap = 0
		end
	end
	for i = 2, 37 do
		if i <= vol or i == self.cap then
			self.vfd.on:blit(surface, x, y, self.vfd.bw, self.vfd.bh)
		else
			self.vfd.off:blit(surface, x, y, self.vfd.bw, self.vfd.bh)
		end
		x = x + self.vfd.bw
	end
	for i = 38, 50 do
		if i <= vol or i == self.cap then
			self.vfd.peakon:blit(surface, x, y, self.vfd.bw, self.vfd.h)
		else
			self.vfd.peakoff:blit(surface, x, y, self.vfd.bw, self.vfd.h)
		end
		x = x + self.vfd.bw
	end
end

function drawVFDStatic(tbl, surface) 
	tbl.vfd.center:blit(surface, tbl.x, tbl.y, tbl.w, tbl.h)
	tbl.vfd.blead[1]:blit(surface, tbl.x, tbl.left.y,  tbl.vfd.lw, tbl.vfd.lh)
	tbl.vfd.blead[2]:blit(surface, tbl.x, tbl.right.y, tbl.vfd.lw, tbl.vfd.lh)
end


function draw25FrameVuMeter(self, surface, vol)
	local val = math.min(math.floor(vol/2), 24)
	if val >= self.cap then
		self.cap = val
	elseif self.cap > 0 then
		self.cap = self.cap -1
	end
	self.img:blitClip(self.cap * self.w, self.src_y, self.w, self.h, surface, self.x, self.y)
end

function nullDraw(self, surface)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

