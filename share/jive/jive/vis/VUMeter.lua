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

RTZP_VALUES = {
	-- cap value decreases one level for each frame rendered - legacy jivelite behaviour
	-1,
	-- sampled volume level is rendered
	0,

	-- if the following values are set then measured (dynamic) FPS value
	-- is to calculate the decrease in volume cap
	1,
--	1.1,
	1.25,
--	1.2,
--	1.3,
--	1.4,
	1.5,
--	1.6,
	1.75,
--	1.8,
--	1.9,
	2,
--	0.9,
--	0.8,
--	0.7,
--	0.6,
--	0.5,
}


-- VU meter metadata globals read by NowPlaying
-- frames per second
FPS=0
-- frames count
FC=0
-- number of frames defined for VU Meter
NF=0

local agg_draw_ticks = 0
local max_draw_ticks = 0
local min_draw_ticks = 1000
local sample_count_draw_ticks = 0


local TWO_SECS_FRAME_COUNT = FRAME_RATE * 2

function __init(self, style)
	local obj = oo.rawnew(self, Icon(style))

	obj.style = style

--	obj.cap = { 0, 0 }

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
	elseif self.style == "vumeter_v2" then
		self.bgImg = nil
	end
end

-- FIXME dynamic based on number of volume levels
local RMS_MAP = {
	   0,    2,    5,    7,   10,   21,   33,   45,   57,   82,
	 108,  133,  159,  200,  242,  284,  326,  387,  448,  509,
	 570,  652,  735,  817,  900, 1005, 1111, 1217, 1323, 1454,
	1585, 1716, 1847, 2005, 2163, 2321, 2480, 2666, 2853, 3040,
	3227, 3414, 3601, 3788, 3975, 4162, 4349, 4536,
	4755, 5000,
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
	local y = params.y
	local x = params.x
	local th = params.th
	local tw = params.tw
	local cap = params.simulated_vol

	for i = 1, params.bars do
		if i == math.floor(cap / 2) then
			params.tickCap:blit(surface, x, y, tw, th)
		elseif i < params.vol then
			params.tickOn:blit(surface, x, y, tw, th)
		else
			params.tickOff:blit(surface, x, y, tw, th)
		end

		y = y - params.th
	end
end

local function drawCompose1(params, surface, volIn)
	local vol = params.vol
	local x = params.x + params.compose1.bar_rxo
	local y = params.y
	local pkh_vol = params.peak_hold_vol
	local bw = params.compose1.bw
	local bh = params.compose1.bh
	local h = params.compose1.h
	local iDB0 = params.db0 + 1

	-- 1 = 0 => no bars ON -
	for i = 2, iDB0 do
		if i <= vol or i == pkh_vol then
			params.compose1.on:blit(surface, x, y, bw, bh)
		else
			params.compose1.off:blit(surface, x, y, bw, bh)
		end
		x = x + params.compose1.barwidth
	end
	for i = iDB0+1, params.volume_levels do
		if i <= vol or i == pkh_vol then
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


local function drawVUMeterFrames(params, surface, _)
	params.img:blitClip(params.simulated_vol * params.w, params.src_y,
								params.w, params.h, surface, params.x, params.y)
end

local function drawVUMeterDiscreteFrames(params, surface, _)
	params.image_frames[params.simulated_vol + params.firstframe_index]:blit(surface, params.x, params.y)
end

local function nullDraw(_, _, _)
end


local function add_vol_components(params, vutbl)
	params.decay_level = 0.0
	params.decay_step = ((vutbl.volume_levels / FPS) / vutbl.rtzp)
	params.peak_hold_vol = 0
	params.peak_hold_counter = 0
	params.simulated_vol = 0
	params.rtzp = vutbl.rtzp
	params.volume_levels = vutbl.volume_levels
end

function _layout(self)
	agg_draw_ticks = 0
	max_draw_ticks = 0
	min_draw_ticks = 1000
	sample_count_draw_ticks = 0

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
		self.left = {
			decay_level=0, peak_hold_vol=0, peak_hold_counter=0, simulated_vol=0,
			x = x + l + ((vu_w - tw * 2) / 3),
			y = y + t + (bars * th),
			bars = bars,
			tw = tw,
			th = th,
			tickOn = self.tickOn,
			tickOff = self.tickOff,
			tickCap = self.tickCap,
			volume_levels = 25,
		}
		self.right =  {
			decay_level=0, peak_hold_vol=0, peak_hold_counter=0, simulated_vol=0,
			x = x + l + ((vu_w - tw * 2) / 3) * 2 + tw,
			y = y + t + (bars * th),
			bars = bars,
			tw = tw,
			th = th,
			tickOn = self.tickOn,
			tickOff = self.tickOff,
			tickCap = self.tickCap,
			volume_levels = 25,
		}
		self.drawMeter = drawVuMeter
		self.bgParams = { bgImg = self.bgImg, bounds=self:getBounds() }
		self.drawBackground = drawVuMeterBackground
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
				self.left  = {
				  img=self.vutbl.imageFrames[1], x=lx , y=fy, src_y=src_y, w=frame_w, h=imgH,
				  framecount = self.vutbl.jsData.framecount,
				}
				self.right = {
				  img=self.vutbl.imageFrames[2], x=rx , y=fy, src_y=src_y, w=frame_w, h=imgH,
				  framecount = self.vutbl.jsData.framecount,
				}
				add_vol_components(self.left, self.vutbl)
				add_vol_components(self.right, self.vutbl)
				log:debug("rtzp : ", self.left.rtzp)
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
				x=(compose1x + self.compose1.lw), y=y1,
				maxVU = self.compose1.maxVU,
				db0 = self.compose1.db0,
				compose1=self.compose1.left,
			}
			self.right = {
				x=(compose1x + self.compose1.lw), y=y2,
				maxVU = self.compose1.maxVU,
				db0 = self.compose1.db0,
				compose1=self.compose1.right,
			}
			add_vol_components(self.left, self.vutbl)
			add_vol_components(self.right, self.vutbl)
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
				self.left  = {
					image_frames=self.vutbl.imageFrames, x=lx , y=fy, src_y=src_y, w=frame_w, h=imgH,
					framecount = self.vutbl.jsData.framecount,
					firstframe_index = ffindx_left,
				}
				self.right = {
					image_frames=self.vutbl.imageFrames, x=rx , y=fy, src_y=src_y, w=frame_w, h=imgH,
					framecount = self.vutbl.jsData.framecount,
					firstframe_index = ffindex_right,
				}
				add_vol_components(self.left, self.vutbl)
				add_vol_components(self.right, self.vutbl)
				log:debug("rtzp : ", self.left.rtzp)
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


local function set_vol_levels(params, vol)
	vol = math.floor(vol * (params.volume_levels/#RMS_MAP)) - 1

	if vol >= params.decay_level or params.rtzp == 0 then
		params.decay_level = vol
		params.simulated_vol = vol
	elseif params.decay_level > 0 then
		if params.rtzp > 0 then
			params.decay_level = math.max(0,
			params.decay_level - params.decay_step)
		else
			params.decay_level = math.max(0, params.decay_level + params.rtzp)
		end
		params.simulated_vol = math.floor(0.5 + params.decay_level)
	end

	if vol >= params.peak_hold_vol then
		params.peak_hold_counter = math.floor(FRAME_RATE/2)
		params.peak_hold_vol = vol
	else
		params.peak_hold_counter = math.max(params.peak_hold_counter - 1, 0)
		if params.peak_hold_counter == 0 then
			params.peak_hold_vol = 0
		end
	end

	params.vol = vol
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

	if self.vutbl ~= nil and  self.vutbl.displayResizing ~= nil then
		local x, y, w, h = self:getBounds()
		local d = self.vutbl.displayResizing
		d.img:blitClip(math.floor((d.c % d.m) /d.d) * d.w, 0, d.w, d.h, surface, (x + (w-d.w)/2), (y + (h-d.h)/2))
		d.c = d.c + 1
		local vuname = visImage:getCurrentVuMeterName()
		local resized = visImage:concurrentResizeVuMeter(vuname, w, h)
		-- reset the frame counter for more accurate FPS calculations
		FC = 0
		if resized == true then
			self:_layout(self)
		end
	end

	local sampleAcc = vis:vumeter()
	local vol = {samplAcc2Vol(sampleAcc[1]), samplAcc2Vol(sampleAcc[2])}

	local draw_ticks = framework:getTicks()
	if self.bgParams ~= nil then
		self.drawBackground(self.bgParams, surface)
	end

	-- local volume = self.player:getVolume()
	set_vol_levels(self.left, vol[1])
	self.drawMeter(self.left, surface, vol[1])
	set_vol_levels(self.right, vol[2])
	self.drawMeter(self.right, surface, vol[2])
	local delta_draw_ticks = framework:getTicks() - draw_ticks
	agg_draw_ticks = agg_draw_ticks + delta_draw_ticks
	max_draw_ticks = math.max(max_draw_ticks, delta_draw_ticks)
	min_draw_ticks = math.min(min_draw_ticks, delta_draw_ticks)
	sample_count_draw_ticks = sample_count_draw_ticks + 1

	if FC == 0 then
		self.lastSampleTicks = ticks
	end
	FC = FC + 1
	-- update FPS every 2 seconds
	if FC % TWO_SECS_FRAME_COUNT == 0 then
		-- minimal work: 1st time around lastSampleTicks == 0, fps calculation will be way off
		-- self corrects next time around
		FPS = (math.floor(TWO_SECS_FRAME_COUNT/((ticks - self.lastSampleTicks)/1000)))
		log:warn("FPS:", FPS, " max:", max_draw_ticks, " min:", min_draw_ticks, " avg:", agg_draw_ticks/sample_count_draw_ticks)
		agg_draw_ticks = 0
		max_draw_ticks = 0
		min_draw_ticks = 1000
		sample_count_draw_ticks = 0
		if NF > 0 then
--			if FPS > (FRAME_RATE * 1.1) then
--				log:warn("FPS HIGH ", FPS, " step:", self.left.framecount/FPS,
--							" FC:", FC, " deltaTicks:", ((ticks - self.lastSampleTicks)/1000))
--			end
			if self.left.framecount/FPS > 1.1 and FPS < FRAME_RATE then
				log:warn("FPS LOW ", FPS, " step:", self.left.framecount/FPS,
							" FC:", FC, " deltaTicks:", ((ticks - self.lastSampleTicks)/1000))
			end
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

Copyright 2025  additions: Blaise Dias
=cut
--]]

