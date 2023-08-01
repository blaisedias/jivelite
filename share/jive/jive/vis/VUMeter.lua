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
		if self.bgImg == nil then
			self.style = "vumeter_v2"
		end
	end
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

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
		local vu_w = w - l - r
		local vu_h = h - t - b

		local tw,th = self.tickOn:getMinSize()

		self.x1 = x + l + ((vu_w - tw * 2) / 3)
		self.x2 = x + l + ((vu_w - tw * 2) / 3) * 2 + tw

		local bars = vu_h / th
		self.y = y + t + (bars * th)
		self.left =  { cap=0,
			x = x + l + ((vu_w - tw * 2) / 3),
			y = y + t + (bars * th),
			bars = bars,
			tw = tw,
			th = th,
			tickOn = self.tickOn,
			tickOff = self.tickOff,
			tickCap = self.tickCap
		}
		self.right =  { cap=0,
			x = x + l + ((vu_w - tw * 2) / 3) * 2 + tw,
			y = y + t + (bars * th),
			bars = bars,
			tw = tw,
			th = th,
			tickOn = self.tickOn,
			tickOff = self.tickOff,
			tickCap = self.tickCap
	 	}
		self.drawMeter = drawVuMeter
		self.bgParams = { bgImg = self.bgImg, bounds=self:getBounds() }
		self.drawBackground = drawVuMeterBackground
	elseif self.style == "vumeter_analog" then
		local imgW, imgH = self.bgImg:getSize()
		local frame_w = imgW/25
		local fx = x + math.floor(w / 2) - frame_w
		self.left =  { img=self.bgImg, x=fx ,                   y=y, src_y=0, w=frame_w, h=imgH, cap=0}
		self.right = { img=self.bgImg, x=self.left.x + frame_w, y=y, src_y=0, w=frame_w, h=imgH, cap=0}
		self.drawMeter = draw25FrameVuMeter
	elseif self.style == "vumeter_v2" then
		log:debug("-----------------------------------------------------------------------")
		self.vutbl, self.vutype = visImage.getVuImage(w,h)
   		if self.vutype == "frame"  then
			self.bgImg = self.vutbl
			if self.bgImg ~= nil then
				local imgW, imgH = self.bgImg:getSize()
				-- FIXME VU Meter images will not always be 25 frames
				local frame_w = imgW/25
				-- centre the VUMeter image within the designated space
				-- horizontally
				local fx = x + math.floor(w / 2) - frame_w
				-- vertically
				local fy = y
				local src_y = 0
				if imgH < h then
					fy = math.floor(y + ((h - imgH)/2))
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
			local y1 = y + math.floor((h - self.vfd.h)/2)
			local y2 = y1 + self.vfd.bh + self.vfd.ch
			self.left =  {x=(vfdx + self.vfd.lw), y=y1, cap=0, peak_hold_counter=0, vfd=self.vfd}
			self.right = {x=(vfdx + self.vfd.lw), y=y2, cap=0, peak_hold_counter=0, vfd=self.vfd}
			self.drawMeter = drawVFD

			self.bgParams = {x=vfdx, y=y1 + self.vfd.bh, vfd=self.vfd, left=self.left, right=self.right}
			self.drawBackground = drawVFDStatic
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
	if self.bgParams ~= nil then
		self.drawBackground(self.bgParams, surface)
	end

	local sampleAcc = vis:vumeter()
	local vol = {samplAcc2Vol(sampleAcc[1]), samplAcc2Vol(sampleAcc[2])}

	-- local volume = self.player:getVolume()

	self.drawMeter(self.left, surface, vol[1]) 
	self.drawMeter(self.right, surface, vol[1]) 
end

function drawVuMeterBackground(params, surface)
	if params.bgImg ~= nil then
		params.bgImg:blit(surface, params.bounds)
	end
end

function drawVuMeter(params, surface, vol)
	-- FIXME when rms map scaled
	local val = math.min(math.floor(vol/2), 24)

--	val = math.floor(math.log(sampleAcc[ch]) * 1.5)
--	if val > 24 then
--		val = 24
--	end

	if val >= params.cap then
		params.cap = val
	elseif params.cap > 0 then
		params.cap = params.cap - 1
	end

	local y = params.y

	for i = 1, params.bars do
		if i == math.floor(params.cap / 2) then
			params.tickCap:blit(surface, params.x, y, params.tw, params.th)
		elseif i < val then
			params.tickOn:blit(surface, params.x, y, params.tw, params.th)
		else
			params.tickOff:blit(surface, params.x, y, params.tw, params.th)
		end

		y = y - th
	end
end

function drawVFD(params, surface, vol)
	-- add vfd bar render x offset here 
	local x = params.x + params.vfd.bar_rxo
	local y = params.y
	if vol >= params.cap then
		params.cap = vol
		params.peak_hold_counter = math.floor(FRAME_RATE/2)
	else
		params.peak_hold_counter = params.peak_hold_counter - 1
		if params.peak_hold_counter < 1 then
			params.cap = 0
		end
	end
	for i = 2, 37 do
		if i <= vol or i == params.cap then
			params.vfd.on:blit(surface, x, y, params.vfd.bw, params.vfd.bh)
		else
			params.vfd.off:blit(surface, x, y, params.vfd.bw, params.vfd.bh)
		end
		x = x + params.vfd.barwidth
	end
	for i = 38, 50 do
		if i <= vol or i == params.cap then
			params.vfd.peakon:blit(surface, x, y, params.vfd.bw, params.vfd.h)
		else
			params.vfd.peakoff:blit(surface, x, y, params.vfd.bw, params.vfd.h)
		end
		x = x + params.vfd.barwidth
	end
end

function drawVFDStatic(params, surface) 
	params.vfd.center:blit(surface, params.x, params.y, params.w, params.h)
	params.vfd.blead[1]:blit(surface, params.x, params.left.y,  params.vfd.lw, params.vfd.lh)
	params.vfd.blead[2]:blit(surface, params.x, params.right.y, params.vfd.lw, params.vfd.lh)
end


function draw25FrameVuMeter(params, surface, vol)
	local val = math.min(math.floor(vol/2), 24)
	if val >= params.cap then
		params.cap = val
	elseif params.cap > 0 then
		params.cap = params.cap -1
	end
	params.img:blitClip(params.cap * params.w, params.src_y, params.w, params.h, surface, params.x, params.y)
end

function nullDraw(params, surface)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

Copyright 2023  additions: Blaise Dias 
=cut
--]]

