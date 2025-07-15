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
local table         = require("jive.utils.table")

local FRAME_RATE    = jive.ui.FRAME_RATE
--local type	= type
local string        = require("jive.utils.string")
local sep = 6

module(...)
oo.class(_M, Icon)

-- Spectrum meter metadata globals read by NowPlaying
-- frames per second
FPS=0
-- frames count
FC=0

local TWO_SECS_FRAME_COUNT = FRAME_RATE * 2

function __init(self, style, windowStyle)
	local obj = oo.rawnew(self, Icon(style))

	obj.val = { 0, 0 }
	obj.np_large_spectrum = false
	if windowStyle == "nowplaying_large_spectrum" then
		obj.np_large_spectrum = true
	end

	obj:addAnimation(function() obj:reDraw() end, FRAME_RATE)

	return obj
end


function _skin(self)
	Icon._skin(self)

-- Black background instead of image
---	self.bgImg = self:styleImage("bgImg")
--	self.bgCol = self:styleColor("bg", { 0xff, 0xff, 0xff, 0xff })

	self.barColor = self:styleColor("barColor", { 0xff, 0xff, 0xff, 0xff })

	self.capColor = self:styleColor("capColor", { 0xff, 0xff, 0xff, 0xff })

	self.desatColor = self:styleColor("desatColor", { 0xff, 0xff, 0xff, 0x20 })
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	-- When used in NP screen _layout gets called with strange values
	if (w <= 0) and (h <= 0) then
		return
	end

	FPS = 0
	FC = 0

	self.channelWidth = {}
	self.clipSubbands = {1,1}
	self.counter = FRAME_RATE * visImage.getVisualiserChangeOnTimerValue()
	self.countDown = self.counter ~= 0

	self.isMono =  0
	if self:styleValue("isMono") ~= nil then
		self.isMono =  self:styleValue("isMono")
	end

--	self.fgImg, self.bgImg, self.dsImg, self.barColor, self.capColor, self.desatColor, self.displayResizing = visImage:getSpectrum(w, h, self.barColor, self.capColor)
--	self.spparms = visImage:getSpectrum(w, h, self.barColor, self.capColor, self:styleValue("capHeight"), self:styleValue("capSpace"))
	self.spparms = visImage:getSpectrum(w, h)

--	self.settings = visImage:getSpectrumMeterSettings(self:styleValue("capHeight"), self:styleValue("capSpace"))
	if self.spparms.barsFormat.barsInBin < 1 then
		self.spparms.barsFormat.barsInBin = 1
	end
	if self.spparms.barsFormat.barWidth < 1 then
		self.spparms.barsFormat.barWidth = 1
	end

	if self:styleValue("clipSubbands") ~= nil then
		self.clipSubbands = self:styleValue("clipSubbands")
	end
	self.backgroundDrawn = false;

	local barsInBin = self.spparms.barsFormat.barsInBin
	local barWidth = self.spparms.barsFormat.barWidth
	local barSpace = self.spparms.barsFormat.barSpace
	local binSpace = self.spparms.barsFormat.binSpace

	local barSize = {}

	barSize[1] = barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace
	barSize[2] = barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace

	self.channelWidth[1] = ((w - l - r) / 2) - (sep - binSpace)
	self.channelWidth[2] = ((w - l - r) / 2) - (sep - binSpace)

	local numBars = vis:spectrum_init(
		self.isMono,

		self.channelWidth[1],
--		self.spparms.channelFlipped[1],
		0,
		barSize[1],
		self.clipSubbands[1],

		self.channelWidth[2],
--		self.spparms.channelFlipped[2],
		0,
		barSize[2],
		self.clipSubbands[2]
	)

	log:debug("-----------------------------------------------------")
	log:debug("** 1: " .. numBars[1] .. " 2: " .. numBars[2])

--	local barHeight = {}
--
--	barHeight[1] = h - t - b - self.spparms.capHeight[1] - self.spparms.capSpace[1]
--	barHeight[2] = h - t - b - self.spparms.capHeight[2] - self.spparms.capSpace[2]
	local barHeight = h - t - b - (self.spparms.capHeight + self.spparms.capSpace)
--	-- doubly ensure no out of bounds scribbling
--	barHeight = barHeight - 4
--	if barHeight > 31 then
--		barHeight = math.floor(barHeight/31) * 31
--	end

	-- max bin value from C code is 31
--	self.barHeightMulti = {}
--	self.barHeightMulti[1] = barHeight[1] / 31
--	self.barHeightMulti[2] = barHeight[2] / 31

	self.xshift = x + l
	self.x1 = x + l + self.channelWidth[1] - numBars[1] * barSize[1] + 2
	self.x2 = x + l + self.channelWidth[2] + binSpace + (sep - binSpace) + (sep - binSpace)
	self.xSpan =  numBars[1] * barSize[1] - binSpace - 1

	-- pre calculate base line height - 20% of a bar
	self.baseLineHeight = math.min(math.ceil((barHeight/31) * 0.2), 2)

	log:debug("** x: " .. x .. " l: " .. l)
	log:debug("** x1: " .. self.x1 .. " x2: " .. self.x2)
	log:debug("** w: " .. w .. " l: " .. l, " r:", r)
	log:debug("** b: " .. b .. " t: " .. t, " xshift: ", self.xshift)

	self.y = y + h - b
	self.h = h
	self.yCentre = self.y - (self.h/2)
	self.yoffset_controls = 0
	if self.np_large_spectrum then
		-- Adjust for large spectrum - where the visualiser background image
		-- occupies the whole screen and controls are overlaid on the background image
		self.y = y + h
		self.yCentre = self.y - (self.h/2)
		-- bar rendering must not spill over the controls area
		-- FIXME: b works but it should really be height of the controls bar
		self.yoffset_controls = b
	end

--	self.cap = { {}, {} }
--	for i = 1, numBars[1] do
--		self.cap[1][i] = 0
--	end
--
--	for i = 1, numBars[2] do
--		self.cap[2][i] = 0
--	end
	log:info("** fg: ", self.spparms.fgImg, " bg: ", self.spparms.bgImg, " ds: ", self.spparms.dsImg)
	log:info("** C: ", self.spparms.capColor, " B: ", self.spparms.barColor, " D: ", self.spparms.desatColor)

	self.left = table.clone(self.spparms.barsFormat)
	self.left.fgImg = self.spparms.fgImg
	self.left.bgImg = self.spparms.bgImg
	self.left.dsImg = self.spparms.dsImg
	self.left.xshift = self.xshift
	self.left.y = self.y
	self.left.h = self.h
	self.left.yCentre = self.yCentre
	self.left.yoffset_controls = self.yoffset_controls
	self.left.barColor = self.spparms.barColor
	self.left.capColor = self.spparms.capColor
	self.left.desatColor = self.spparms.desatColor
	self.left.turbine = self.spparms.turbine
	self.left.fill = self.spparms.fill
	self.left.barSize = self.left.barWidth + self.left.barSpace
	self.left.xStep = self.left.barWidth * self.left.barsInBin + self.left.barSpace * (self.left.barsInBin - 1) + self.left.binSpace
	self.left.barStep = self.left.barWidth - 1
	self.left.halfHeight = self.left.h/2
	self.left.adjustedHeight = self.left.h - self.left.yoffset_controls
	self.left.adjustedY = self.left.y - self.left.yoffset_controls
	self.left.barHeightMulti = barHeight / 31
	self.left.flip = 0 ~= self.spparms.channelFlipped[1]
	self.left.cap = {}
	for i = 1, numBars[1] do
		self.left.cap[i] = 0
	end
	self.left.capHeight = self.spparms.capHeight
	self.left.capSpace = self.spparms.capSpace
	self.left.totalCapHeight = self.left.capHeight + self.left.capSpace

	self.right = table.clone(self.left)
	self.right.flip = 0 ~= self.spparms.channelFlipped[2]

	self.left.x = x + l + self.channelWidth[1] - numBars[1] * barSize[1] + 2

	self.right.x = x + l + self.channelWidth[2] + binSpace + (sep - binSpace) + (sep - binSpace)

--	log:info("**** left:", table.stringify(self.left))
--	log:info("**** right:", table.stringify(self.right))
end

local function _drawBins(surface, bch, params)
	--	mutating
	local cch = params.cap
	local x = params.x
	local nz = false

	--	non-mutating
	local xshift = params.xshift
	local xStep = params.xStep

	local y = params.adjustedY
	local adjustedHeight = params.adjustedHeight
	local halfHeight = params.halfHeight

	local barHeightMulti = params.barHeightMulti
	local barsInBin = params.barsInBin
	local barSize = params.barSize
	local barWidth = params.barWidth
	local barStep = params.barStep
	local barColor = params.barColor

	local capColor = params.capColor
	local totalCapHeight = params.totalCapHeight
	local capHeight = params.capHeight
	local capSpace = params.capSpace
	local desatColor = params.desatColor

	local fgImg = params.fgImg
	local fill = params.fill

	local xLeft
	local yTop
	local imgXLeft, imgY
	local yA, yB

	local cStart = 1
	local cEnd = #bch
	local cInc = 1
	if params.flip then
		cStart = #bch
		cEnd = 1
		cInc = -1
	end
	for i = cStart, cEnd, cInc do
		bch[i] = math.ceil(bch[i] * barHeightMulti)

		if cch[i] > 0 then
			cch[i] = math.ceil(cch[i] - barHeightMulti)
			if cch[i] < 0 then
				cch[i] = 0
			end
		end
		if bch[i] >= cch[i] then
			cch[i] = bch[i]
		end

		if fill == 2 then
			bch[i] = cch[i]
		end

		-- partial fill to caps
		if cch[i] > 0 and fill == 1 then
			nz = true
			yTop = y - cch[i] + 1
			dy = cch[i] - bch[i]
			yA = y - cch[i]
			yB = y - bch[i]
			imgY = adjustedHeight - cch[i] + 1
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					if params.dsImg ~= nil then
						params.dsImg:blitClip(imgXLeft, imgY,
									barWidth, cch[i] - bch[i],
									surface,
									xLeft, yTop)
					end
				else
					surface:filledRectangle(
						xLeft,
						yA,
						xLeft + barStep,
						yB,
						desatColor)
				end
			end
		end

		if cch[i] > 0 and capHeight > 0 then
			nz = true
			yTop = y - (cch[i] + totalCapHeight)
			yA = y - (cch[i] + totalCapHeight)
			yB = y - (cch[i] + capSpace)
			imgY = adjustedHeight - (cch[i] + totalCapHeight)
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					fgImg:blitClip(imgXLeft, imgY,
									barWidth, capHeight,
									surface,
									xLeft, yTop)
				else
					surface:filledRectangle(
						xLeft,
						yA,
						xLeft + barStep,
						yB,
						capColor)
				end
   			end
		end

		-- bar
		if bch[i] > 0 then
			nz = true
			yTop = y - bch[i] + 1
			yC = adjustedHeight - bch[i] + 1
			yA = y - bch[i] + 1
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					fgImg:blitClip(imgXLeft, yC,
									barWidth, bch[i],
									surface,
									xLeft, yTop)
				else
					surface:filledRectangle(
						xLeft, y,
						xLeft + barStep, yA,
						barColor
						)
				end
			end
		end

		x = x + xStep
	end
	return nz
end

local function _drawTurbineBins(surface, bch, params)
	--	mutating
	local cch = params.cap
	local x = params.x
	local nz = false

	--	non-mutating
	local xshift = params.xshift
	local xStep = params.xStep

	local y = params.adjustedY
	local yCentre = params.yCentre
	local adjustedHeight = params.adjustedHeight
	local halfHeight = params.halfHeight

	local barHeightMulti = params.barHeightMulti
	local barsInBin = params.barsInBin
	local barSize = params.barSize
	local barWidth = params.barWidth
	local barStep = params.barStep
	local barColor = params.barColor

	local capColor = params.capColor
	local totalCapHeight = params.totalCapHeight
	local capHeight = params.capHeight
	local capSpace = params.capSpace
	local desatColor = params.desatColor

	local fgImg = params.fgImg
	local fill = params.fill

	local xLeft
	local yTop, yBot
	local imgXLeft

	local dyFill, yT1, yT2, yB1, yB2, xF

	for i = 1, #bch do
		bch[i] = math.ceil(bch[i] * barHeightMulti)

		if cch[i] > 0 then
			cch[i] = math.ceil(cch[i] - barHeightMulti)
			if cch[i] < 0 then
				cch[i] = 0
			end
		end
		if bch[i] >= cch[i] then
			cch[i] = bch[i]
		end
		if fill == 2 then
			bch[i] = cch[i]
		end

		-- partial fill to caps 
		if cch[i] > 0 and fill == 1 then
			dyFill = (cch[i] - bch[i])/2
			nz = true
			yTop = yCentre - (cch[i]/2)
			yBot = yCentre + (cch[i]/2)
			yT1 = halfHeight - (cch[i]/2)
			yT2 = yTop + dyFill
			yB1 = halfHeight + (cch[i]/2) - dyFill
			yB2 = yBot - dyFill
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil and  params.dsImg ~= nil then
					imgXLeft = xLeft - xshift
					params.dsImg:blitClip(imgXLeft, yT1,
								barWidth, dyFill,
								surface,
								xLeft, yTop)
					params.dsImg:blitClip(imgXLeft, yB1,
								barWidth, dyFill,
								surface,
								xLeft, yB2)
				else
					surface:filledRectangle(
						xLeft,
						yTop,
						xLeft + barStep,
						yT2 - 1,
						desatColor)
					surface:filledRectangle(
						xLeft,
--						yBot - dyFill,
						yB2 + 1,
						xLeft + barStep,
						yBot,
						desatColor)
				end
			end
		end

		-- caps 
		if cch[i] > 0 and capHeight > 0 then
			nz = true
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					local y1 = (cch[i] + totalCapHeight)/2
					fgImg:blitClip(imgXLeft, halfHeight - y1,
									barWidth, (capHeight/2),
									surface,
									xLeft, yCentre - y1)
					y1 = (cch[i] + capSpace)/2
					fgImg:blitClip(imgXLeft, halfHeight + y1,
									barWidth, (capHeight/2),
									surface,
									xLeft, yCentre + y1)
				else
					-- fill does at least one horizontal fill if y is the same
					surface:filledRectangle(
						xLeft,
						yCentre - ((cch[i] + totalCapHeight)/2),
						xLeft + barStep,
						yCentre - ((cch[i] + capHeight)/2),
						capColor)
					surface:filledRectangle(
						xLeft,
						yCentre + ((cch[i] + totalCapHeight)/2),
						xLeft + barStep,
						yCentre + ((cch[i] + capHeight)/2),
						capColor)
				end
			end
		end

		-- bar
		if bch[i] > 0 then
			nz = true
			yTop = yCentre - (bch[i]/2)
			yT1 = halfHeight - (bch[i]/2)
			yT2 = yCentre - (bch[i]/2)
			yB2 = yCentre + (bch[i]/2)
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					fgImg:blitClip(imgXLeft, yT1,
									barWidth, bch[i],
									surface,
									xLeft, yTop)
				else
					surface:filledRectangle(
						xLeft,
						yT2,
						xLeft + barStep,
						yB2,
						barColor
						)
				end
			end
		end

		x = x + xStep
	end
	return nz
end

function draw(self, surface)
	local ticks = framework:getTicks()
	if self.countDown then
		self.counter = self.counter - 1
		if self.counter < 1 then
			visImage:spChange('force', 'force')
			self:_layout()
		end
	end

-- Black background instead of image
--	self.bgImg:blit(surface, self:getBounds())
	local x, y, w, h = self:getBounds()

	if self.spparms.displayResizing ~= nil then
		local d = self.spparms.displayResizing
		d.img:blitClip(math.floor((d.c % d.m)/d.d) * d.w, 0, d.w, d.h, surface, (x + (w-d.w)/2), (y + (h-d.h)/2))
		d.c = d.c + 1
		if visImage:resizeVisualisers(w, h, self.spparms.rszs, self.spparms.rszOp) then
			self:_layout(self)
		end
		return
	end

--	-- Avoid calling this more than once as it's not necessary
--	if not self.backgroundDrawn then
--		surface:filledRectangle(x, y, x + w, y + h, self.bgCol)
--		self.backgroundDrawn = true
--	end

	if self.spparms.bgImg ~= nil then
		self.spparms.bgImg:blit(surface, x, y)
	end

	local bins = { {}, {} }

	bins[1], bins[2] = vis:spectrum()

	local nz1,nz2
	if self.spparms.turbine then
		nz1 = _drawTurbineBins( surface, bins[1], self.left)
		nz2 = _drawTurbineBins( surface, bins[2], self.right)
	else
		nz1 = _drawBins( surface, bins[1], self.left)
		nz2 = _drawBins( surface, bins[2], self.right)
	end


	-- simulate draw analyzer baseline only if playing,
	-- by not drawing baseline if volume is 0
	-- good enough
	if self.spparms.baselineAlways or ((nz1 or nz2) and self.spparms.baselineOn) then
		local baseLineHeight = self.baseLineHeight
		local halfBaseLineHeight = baseLineHeight/2
		local xSpan = self.xSpan
		if self.spparms.fgImg ~= nil then
			if self.spparms.turbine then
				self.spparms.fgImg:blitClip(self.x1 - x, (h/2) - halfBaseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x1, self.yCentre - halfBaseLineHeight)
				self.spparms.fgImg:blitClip(self.x2 - x, (h/2) - halfBaseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x2, self.yCentre - halfBaseLineHeight)
			else
				self.spparms.fgImg:blitClip(self.x1 - x, h - self.yoffset_controls - baseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x1, self.y - self.yoffset_controls - baseLineHeight)
				self.spparms.fgImg:blitClip(self.x2 - x, h - self.yoffset_controls - baseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x2, self.y - self.yoffset_controls - baseLineHeight)
			end
		else
			if self.spparms.turbine then
				surface:filledRectangle(self.x1, self.yCentre - halfBaseLineHeight, self.x1 + xSpan ,
										self.yCentre + baseLineHeight - halfBaseLineHeight, self.spparms.barColor)
				surface:filledRectangle(self.x2, self.yCentre - halfBaseLineHeight, self.x2 + xSpan ,
										self.yCentre + baseLineHeight - halfBaseLineHeight, self.spparms.barColor)
			else
				surface:filledRectangle(self.x1, self.y - baseLineHeight - self.yoffset_controls,
										self.x1 + xSpan, self.y - self.yoffset_controls, self.spparms.barColor)
				surface:filledRectangle(self.x2, self.y - baseLineHeight - self.yoffset_controls,
										self.x2 + xSpan, self.y - self.yoffset_controls, self.spparms.barColor)
			end
		end
	end

	if FC == 0 then
		self.lastSampleTicks = ticks
	end
	FC = FC + 1
	-- update FPS every 2 seconds
	if FC % TWO_SECS_FRAME_COUNT == 0 then
		-- minimal work: 1st time around lastSampleTicks == 0, fps calculation will be way off
		-- self corrects next time around
		FPS = math.floor(TWO_SECS_FRAME_COUNT/((ticks - self.lastSampleTicks)/1000))
		self.lastSampleTicks = ticks
	end
end

function twiddle(self)
	visImage:spChange('force', 'force')
	self:_layout()
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

Copyright 2023  additions: Blaise Dias
=cut
--]]

