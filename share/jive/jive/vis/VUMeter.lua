local oo            = require("loop.simple")
local math          = require("math")

--local Framework     = require("jive.ui.Framework")
local Icon          = require("jive.ui.Icon")
--local Surface       = require("jive.ui.Surface")
--local Timer         = require("jive.ui.Timer")
--local Widget        = require("jive.ui.Widget")

local vis           = require("jive.vis")
local visImage      = require("jive.visImage")

--local debug         = require("jive.utils.debug")
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

local function drawVuMeterBackground(params, surface)
	if params.bgImg ~= nil then
		params.bgImg:blit(surface, params.bounds)
	end
end

local function drawVuMeter(params, surface, vol)
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
	local x = params.x
	local th = params.th
	local tw = params.tw
	local cap = params.cap

	for i = 1, params.bars do
		if i == math.floor(cap / 2) then
			params.tickCap:blit(surface, x, y, tw, th)
		elseif i < val then
			params.tickOn:blit(surface, x, y, tw, th)
		else
			params.tickOff:blit(surface, x, y, tw, th)
		end

		y = y - params.th
	end
end

local function drawVFD(params, surface, vol)
	-- add vfd bar render x offset here
	if vol >= params.cap then
		params.cap = vol
		params.peak_hold_counter = math.floor(FRAME_RATE/2)
	else
		params.peak_hold_counter = params.peak_hold_counter - 1
		if params.peak_hold_counter < 1 then
			params.cap = 0
		end
	end

	local x = params.x + params.vfd.bar_rxo
	local y = params.y
	local cap = params.cap
	local bw = params.vfd.bw
	local bh = params.vfd.bh
	local h = params.vfd.h

	for i = 2, 37 do
		if i <= vol or i == cap then
			params.vfd.on:blit(surface, x, y, bw, bh)
		else
			params.vfd.off:blit(surface, x, y, bw, bh)
		end
		x = x + params.vfd.barwidth
	end
	for i = 38, 50 do
		if i <= vol or i == cap then
			params.vfd.peakon:blit(surface, x, y, bw, h)
		else
			params.vfd.peakoff:blit(surface, x, y, bw, h)
		end
		x = x + params.vfd.barwidth
	end
end

local function drawVFDStatic(params, surface)
	params.vfd.center:blit(surface, params.x, params.y, params.w, params.h)
	params.vfd.leftlead:blit(surface, params.x, params.left.y,  params.vfd.lw, params.vfd.lh)
	params.vfd.rightlead:blit(surface, params.x, params.right.y, params.vfd.lw, params.vfd.lh)
end


local function draw25FrameVuMeter(params, surface, vol)
	local val = math.min(math.floor(vol/2), 24)
	if val >= params.cap then
		params.cap = val
	elseif params.cap > 0 then
		params.cap = params.cap -1
	end
	params.img:blitClip(params.cap * params.w, params.src_y, params.w, params.h, surface, params.x, params.y)
end

local function nullDraw(_, _, _)
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	self.counter = FRAME_RATE * visImage:getVisualiserChangeOnTimerValue()
	self.countDown = self.counter ~= 0

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

	self.bgParams = nil

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
		self.drawMeter = nullDraw
		log:debug("-----------------------------------------------------------------------")
		self.vutbl = visImage:getVuImage(w,h)
		if self.vutbl.displayResizing ~= nil then
			return
		end
		if self.vutbl.vutype == "frame"  then
			self.bgImg = self.vutbl.bgImg
			if self.bgImg ~= nil then
				local imgW, imgH = self.bgImg:getSize()
				-- FIXME VU Meter images will not always be 25 frames
				local frame_w = imgW/25
				-- centre the VUMeter image within the designated space
				-- horizontally
--				local lx = x + math.floor(w / 4) - math.floor(frame_w / 2)
--				local rx = x + math.floor((3*w) / 4) - math.floor(frame_w / 2)
				local spacing = math.floor((w - frame_w - frame_w)/3)
				local lx = x + spacing
				local rx = lx + frame_w + spacing
				-- vertically
				local fy = y
				local src_y = 0
				if imgH < h then
					fy = math.floor(y + ((h - imgH)/2))
				elseif imgH > h then
					-- clip the image at the top and bottom
					src_y = math.floor((imgH - h)/2)
				end
				self.left =  { img=self.bgImg, x=lx ,                   y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
--				self.right = { img=self.bgImg, x=self.left.x + frame_w, y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
				self.right = { img=self.bgImg, x=rx ,                   y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
				log:debug("frame_w : ", frame_w, " spacing: ", spacing)
				log:debug("left : x:", self.left.x, " y:", self.left.y, " src_y:",
							self.left.src_y, " w:", self.left.w, " h:", self.left.h)
				log:debug("right: x:", self.right.x, " y:", self.right.y, " src_y:", self.right.src_y,
							" w:", self.right.w, " h:", self.right.h)
				self.drawMeter = draw25FrameVuMeter
			else
				self.left =  { img=nil }
				self.right = { img=nil }
				self.drawMeter = nullDraw
			end
		elseif self.vutbl.vutype == "25framesLR"  then
			if self.vutbl.leftImg ~= nil and self.vutbl.rightImg ~= nil then
				local imgW, imgH = self.vutbl.leftImg:getSize()
				-- FIXME VU Meter images will not always be 25 frames
				local frame_w = imgW/25
				-- centre the VUMeter image within the designated space
				-- horizontally
--				local lx = x + math.floor(w / 4) - math.floor(frame_w / 2)
--				local rx = x + math.floor((3*w) / 4) - math.floor(frame_w / 2)
				local spacing = math.floor((w - frame_w - frame_w)/3)
				local lx = x + spacing
				local rx = lx + frame_w + spacing
				-- vertically
				local fy = y
				local src_y = 0
				if imgH < h then
					fy = math.floor(y + ((h - imgH)/2))
				elseif imgH > h then
					-- clip the image at the top and bottom
					src_y = math.floor((imgH - h)/2)
				end
				self.left =  { img=self.vutbl.leftImg, x=lx ,                   y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
				self.right = { img=self.vutbl.rightImg, x=rx ,                   y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0}
				log:debug("frame_w : ", frame_w, " spacing: ", spacing)
				log:debug("left : x:", self.left.x, " y:", self.left.y, " src_y:",
							self.left.src_y, " w:", self.left.w, " h:", self.left.h)
				log:debug("right: x:", self.right.x, " y:", self.right.y, " src_y:", self.right.src_y,
							" w:", self.right.w, " h:", self.right.h)
				self.drawMeter = draw25FrameVuMeter
			else
				self.left =  { img=nil }
				self.right = { img=nil }
				self.drawMeter = nullDraw
			end
		elseif self.vutbl.vutype == "vfd" then
			self.vfd = self.vutbl.vfd
			local vfdx = x + math.floor((w - self.vfd.w)/2)
			local y1 = y + math.floor((h - self.vfd.h)/2)
			local y2 = y1 + self.vfd.bh + self.vfd.ch
			self.left =  {x=(vfdx + self.vfd.lw), y=y1, cap=0, peak_hold_counter=0, vfd=self.vfd.left}
			self.right = {x=(vfdx + self.vfd.lw), y=y2, cap=0, peak_hold_counter=0, vfd=self.vfd.right}
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

local function samplAcc2Vol(sampleAcc)
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc > RMS_MAP[i] then
			return i
		end
	end
	return 1
end

function draw(self, surface)
	if self.countDown then
		self.counter = self.counter - 1
		if self.counter < 1 then
			visImage:vuChange('force', 'force')
			self:_layout(self)
		end
	end

	if self.bgParams ~= nil then
		self.drawBackground(self.bgParams, surface)
	end

	if self.vutbl ~= nil and  self.vutbl.displayResizing ~= nil then
		local x, y, w, h = self:getBounds()
		local d = self.vutbl.displayResizing
		d.img:blitClip(math.floor((d.c % d.m) /d.d) * d.w, 0, d.w, d.h, surface, (x + (w-d.w)/2), (y + (h-d.h)/2))
		d.c = d.c + 1
		local vuname = visImage:getCurrentVuMeterName()
		local resized = visImage:concurrentResizeVuMeter(vuname, w, h)
		if resized == true then
			self:_layout(self)
		end
	end

	local sampleAcc = vis:vumeter()
	local vol = {samplAcc2Vol(sampleAcc[1]), samplAcc2Vol(sampleAcc[2])}

	-- local volume = self.player:getVolume()

	self.drawMeter(self.left, surface, vol[1])
	self.drawMeter(self.right, surface, vol[2])
end

function twiddle(self)
	visImage:vuChange('force', 'force')
	self:_layout(self)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

Copyright 2023  additions: Blaise Dias
=cut
--]]

