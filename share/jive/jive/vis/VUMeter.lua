local oo            = require("loop.simple")
local math          = require("math")

--local Framework     = require("jive.ui.Framework")
local Icon          = require("jive.ui.Icon")
--local Surface       = require("jive.ui.Surface")
--local Timer         = require("jive.ui.Timer")
--local Widget        = require("jive.ui.Widget")

local vis           = require("jive.vis")
local visImage      = require("jive.visImage")
local framework     = require("jive.ui.Framework")

--local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jivelite.vis")

local FRAME_RATE    = jive.ui.FRAME_RATE

local appletManager = appletManager

module(...)
oo.class(_M, Icon)


-- VU meter metadata globals read by NowPlaying
-- frames per second
FPS=0
-- frames count
FC=0
-- number of frames defined for VU Meter
NF=0

local TWO_SECS_FRAME_COUNT = FRAME_RATE * 2

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

-- FIXME dynamic based on number of bars
local RMS_MAP = {
	   0,    2,    5,    7,   10,   21,   33,   45,   57,   82,
	 108,  133,  159,  200,  242,  284,  326,  387,  448,  509,
	 570,  652,  735,  817,  900, 1005, 1111, 1217, 1323, 1454,
	1585, 1716, 1847, 2005, 2163, 2321, 2480, 2666, 2853, 3040,
	3227, 3414, 3601, 3788, 3975, 4162, 4349, 4536, 4755, 5000,
}

local function samplAcc2Vol(sampleAcc)
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc > RMS_MAP[i] then
			return i
		end
	end
	return 1
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

local function drawCompose1(params, surface, volIn)
	local vol = math.min(params.maxVU - 1, (volIn * params.maxVU)/#RMS_MAP)

	-- add compose1 bar render x offset here
	if vol >= params.cap then
		params.cap = vol
		params.peak_hold_counter = math.floor(FRAME_RATE/2)
	else
		params.peak_hold_counter = params.peak_hold_counter - 1
		if params.peak_hold_counter < 1 then
			params.cap = 0
		end
	end

	local x = params.x + params.compose1.bar_rxo
	local y = params.y
	local cap = params.cap
	local bw = params.compose1.bw
	local bh = params.compose1.bh
	local h = params.compose1.h
	local iDB0 = params.db0 + 1

	-- 1 = 0 => no bars ON -
	for i = 2, iDB0 do
		if i <= vol or i == cap then
			params.compose1.on:blit(surface, x, y, bw, bh)
		else
			params.compose1.off:blit(surface, x, y, bw, bh)
		end
		x = x + params.compose1.barwidth
	end
	for i = iDB0+1, params.maxVU do
		if i <= vol or i == cap then
			params.compose1.peakon:blit(surface, x, y, bw, h)
		else
			params.compose1.peakoff:blit(surface, x, y, bw, h)
		end
		x = x + params.compose1.barwidth
	end
end

local function drawCompose1Static(params, surface)
	params.compose1.center:blit(surface, params.x, params.y, params.w, params.h)
	params.compose1.leftlead:blit(surface, params.x, params.left.y,  params.compose1.lw, params.compose1.lh)
	params.compose1.rightlead:blit(surface, params.x, params.right.y, params.compose1.lw, params.compose1.lh)
	params.compose1.lefttrail:blit(surface, params.xtrail, params.left.y,  params.compose1.tw, params.compose1.th)
	params.compose1.righttrail:blit(surface, params.xtrail, params.right.y, params.compose1.tw, params.compose1.th)
end


local function drawVUMeterFrames(params, surface, vol)
	local val = math.min(math.floor(vol * (params.framecount/#RMS_MAP)), params.framecount - 1)
	if val >= params.cap then
		params.cap = val
	elseif params.cap > 0 then
		params.cap = math.max(0, params.cap - (params.framecount/FPS))
	end
	params.img:blitClip(math.floor(params.cap) * params.w, params.src_y, params.w, params.h, surface, params.x, params.y)
end

local function drawVUMeterDiscreteFrames(params, surface, vol)
	local val = math.min(math.floor(vol * (params.framecount/#RMS_MAP)), params.framecount - 1)
	if val >= params.cap then
		params.cap = val
	elseif params.cap > 0 then
		params.cap = math.max(0, params.cap - (params.framecount/FPS))
	end
	params.image_frames[math.floor(params.cap) + params.firstframe_index]:blit(surface, params.x, params.y)
end

local function nullDraw(_, _, _)
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	self.counter = FRAME_RATE * visImage:getVisualiserChangeOnTimerValue()
	self.countDown = self.counter ~= 0

	self.player = appletManager:callService("getCurrentPlayer")

	-- if FPS is 0 => FPS is unmeasured, so use FRAME_RATE
	-- If actual frame rate differs significantly from FRAME_RATE
	-- the first 120 frames would rendered "incorrectly"
	if FPS == 0 then
		FPS = FRAME_RATE
	end
	NF = 0
	FC = 0

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
--	elseif self.style == "vumeter_analog" then
--		local imgW, imgH = self.bgImg:getSize()
--		local frame_w = imgW/25
--		local fx = x + math.floor(w / 2) - frame_w
--		self.left =  { img=self.bgImg, x=fx ,                   y=y, src_y=0, w=frame_w, h=imgH, cap=0}
--		self.right = { img=self.bgImg, x=self.left.x + frame_w, y=y, src_y=0, w=frame_w, h=imgH, cap=0}
--		self.drawMeter = draw25FrameVuMeter
	elseif self.style == "vumeter_v2" then
		self.drawMeter = nullDraw
		self.vutbl = visImage:getVuImage(w,h)
		if self.vutbl.displayResizing ~= nil then
			return
		end
		if self.vutbl.vutype == "frames" then
			if self.vutbl.imageFrames[1] ~= nil then
				-- FIXME: frame images for multiple channels must have the same characteristics.
				local imgW, imgH = self.vutbl.imageFrames[1]:getSize()
				log:info("frame count: ", self.vutbl.jsData.framecount)
				NF = self.vutbl.jsData.framecount
				local frame_w = imgW/self.vutbl.jsData.framecount
				-- place the VUMeter images within the designated space
				-- with equal spacing on the left, right and centre
				local spacing = math.floor((w - frame_w - frame_w)/3)
				local lx = x + spacing
				local rx = lx + frame_w + spacing
				-- centre vertically
				local fy = y
				local src_y = 0
				if imgH < h then
					fy = math.floor(y + ((h - imgH)/2))
				elseif imgH > h then
					-- clip the image at the top and bottom
					src_y = math.floor((imgH - h)/2)
				end
				self.left  = { img=self.vutbl.imageFrames[1], x=lx , y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0,
								framecount = self.vutbl.jsData.framecount,
							}
				self.right = { img=self.vutbl.imageFrames[2], x=rx , y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0,
								framecount = self.vutbl.jsData.framecount,
							}
				log:debug("frame_w : ", frame_w, " spacing: ", spacing)
				log:debug("left : x:", self.left.x, " y:", self.left.y, " src_y:",
							self.left.src_y, " w:", self.left.w, " h:", self.left.h)
				log:debug("right: x:", self.right.x, " y:", self.right.y, " src_y:", self.right.src_y,
							" w:", self.right.w, " h:", self.right.h)
				self.drawMeter = drawVUMeterFrames
			else
				self.left =  { img=nil }
				self.right = { img=nil }
				self.drawMeter = nullDraw
			end
		elseif self.vutbl.vutype == "compose1" then
			self.compose1 = self.vutbl.compose1
			local compose1x = x + math.floor((w - self.compose1.w)/2)
			local xtrail = compose1x + self.compose1.lw + (49 * self.compose1.left.barwidth)
			local y1 = y + math.floor((h - self.compose1.h)/2)
			local y2 = y1 + self.compose1.bh + self.compose1.ch
			self.left =  {
				x=(compose1x + self.compose1.lw), y=y1, cap=0, peak_hold_counter=0,
				maxVU = self.compose1.maxVU,
				db0 = self.compose1.db0,
				compose1=self.compose1.left
			}
			self.right = {
				x=(compose1x + self.compose1.lw), y=y2, cap=0, peak_hold_counter=0,
				maxVU = self.compose1.maxVU,
				db0 = self.compose1.db0,
				compose1=self.compose1.right
			}
			self.drawMeter = drawCompose1

			self.bgParams = {x=compose1x, y=y1 + self.compose1.bh, compose1=self.compose1, left=self.left, right=self.right, xtrail = xtrail}
			self.drawBackground = drawCompose1Static
		elseif self.vutbl.vutype == "discreteframes" then
				-- FIXME: frame images for multiple channels must have the same characteristics.
				local frame_w, imgH = self.vutbl.imageFrames[1]:getSize()
				log:info("frame count: ", self.vutbl.jsData.framecount, " ",  #self.vutbl.imageFrames)
				NF = self.vutbl.jsData.framecount
				local ffindx_left = 1
				local ffindex_right = ffindx_left
				if #self.vutbl.imageFrames == 2*self.vutbl.jsData.framecount then
					ffindex_right = self.vutbl.jsData.framecount + 1
				end
				-- place the VUMeter images within the designated space
				-- with equal spacing on the left, right and centre
				local spacing = math.floor((w - frame_w - frame_w)/3)
				local lx = x + spacing
				local rx = lx + frame_w + spacing
				-- centre vertically
				local fy = y
				local src_y = 0
				if imgH < h then
					fy = math.floor(y + ((h - imgH)/2))
				elseif imgH > h then
					-- clip the image at the top and bottom
					src_y = math.floor((imgH - h)/2)
				end
				self.left  = { image_frames=self.vutbl.imageFrames, x=lx , y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0,
								framecount = self.vutbl.jsData.framecount,
								firstframe_index = ffindx_left,
							}
				self.right = { image_frames=self.vutbl.imageFrames, x=rx , y=fy, src_y=src_y, w=frame_w, h=imgH, cap=0,
								framecount = self.vutbl.jsData.framecount,
								firstframe_index = ffindex_right,
							}
				log:debug("frame_w : ", frame_w, " spacing: ", spacing)
				log:debug("left : x:", self.left.x, " y:", self.left.y, " src_y:",
							self.left.src_y, " w:", self.left.w, " h:", self.left.h)
				log:debug("right: x:", self.right.x, " y:", self.right.y, " src_y:", self.right.src_y,
							" w:", self.right.w, " h:", self.right.h)
				self.drawMeter = drawVUMeterDiscreteFrames
		else
			log:warn("unknown vutype ", self.vutbl.vutype)
		end
	else
		log:warn("unknown VU style ", self.style)
	end
end


function draw(self, surface)
	local ticks = framework:getTicks()
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

	if FC == 0 then
		self.lastSampleTicks = ticks
	end
	FC = FC + 1
	-- update FPS every 2 seconds
	if FC % TWO_SECS_FRAME_COUNT == 0 then
		-- minimal work: 1st time around lastSampleTicks == 0, fps calculation will be way off
		-- self corrects next time around
		FPS = (math.floor(TWO_SECS_FRAME_COUNT/((ticks - self.lastSampleTicks)/1000)))
		if self.left.framecount/FPS > 1.1 then
			log:warn("FPS LOW ", FPS, " step:", self.left.framecount/FPS)
		end
		if FPS > FRAME_RATE then
			log:warn("FPS HIGH ", FPS, " step:", self.left.framecount/FPS)
		end
		self.lastSampleTicks = ticks
	end
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

