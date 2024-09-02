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
local table         = require("jive.utils.table")

local FRAME_RATE    = jive.ui.FRAME_RATE
--local type	= type
local string        = require("jive.utils.string")
local sep = 6

module(...)
oo.class(_M, Icon)


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
	self.bgCol = self:styleColor("bg", { 0xff, 0xff, 0xff, 0xff })

	self.barColor = self:styleColor("barColor", { 0xff, 0xff, 0xff, 0xff })

	self.capColor = self:styleColor("capColor", { 0xff, 0xff, 0xff, 0xff })
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	-- When used in NP screen _layout gets called with strange values
	if (w <= 0) and (h <= 0) then
		return
	end

	self.channelWidth = {}
	self.clipSubbands = {}
	self.counter = FRAME_RATE * visImage.getVisualiserChangeOnTimerValue()
	self.countDown = self.counter ~= 0

	self.isMono =  self:styleValue("isMono")

	self.fgImg, self.bgImg, self.bgAlpha, self.barColor, self.capColor, self.displayResizing = visImage:getSpectrum(w, h, self.barColor, self.capColor)

--	if self.displayResizing ~= nil then
--		self.counter = FRAME_RATE/2
--	end

	log:info('** barColor=', string.format("0x%x", self.barColor), " capColor=", string.format("0x%x",self.capColor))
	self.settings = visImage:getSpectrumMeterSettings(self:styleValue("capHeight"), self:styleValue("capSpace"))
	if self.settings.barsFormat.barsInBin < 1 then
		self.settings.barsFormat.barsInBin = 1
	end
	if self.settings.barsFormat.barWidth < 1 then
		self.settings.barsFormat.barWidth = 1
	end

	self.clipSubbands = self:styleValue("clipSubbands")
	self.backgroundDrawn = false;

	local barsInBin = self.settings.barsFormat.barsInBin
	local barWidth = self.settings.barsFormat.barWidth
	local barSpace = self.settings.barsFormat.barSpace
	local binSpace = self.settings.barsFormat.binSpace

	local barSize = {}

	barSize[1] = barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace
	barSize[2] = barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace

	self.channelWidth[1] = ((w - l - r) / 2) - (sep - binSpace)
	self.channelWidth[2] = ((w - l - r) / 2) - (sep - binSpace)

	local numBars = vis:spectrum_init(
		self.isMono,

		self.channelWidth[1],
		self.settings.channelFlipped[1],
		barSize[1],
		self.clipSubbands[1],

		self.channelWidth[2],
		self.settings.channelFlipped[2],
		barSize[2],
		self.clipSubbands[2]
	)

	log:debug("-----------------------------------------------------")
	log:debug("** 1: " .. numBars[1] .. " 2: " .. numBars[2])

--	local barHeight = {}
--
--	barHeight[1] = h - t - b - self.settings.capHeight[1] - self.settings.capSpace[1]
--	barHeight[2] = h - t - b - self.settings.capHeight[2] - self.settings.capSpace[2]
	local barHeight = h - t - b - self.settings.capHeight - self.settings.capSpace

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
	log:info("** b: " .. b .. " t: " .. t, " xshift: ", self.xshift)

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

	self.left = table.clone(self.settings.barsFormat)
	self.left.fgImg = self.fgImg
	self.left.xshift = self.xshift
	self.left.y = self.y
	self.left.h = self.h
	self.left.yCentre = self.yCentre
	self.left.yoffset_controls = self.yoffset_controls
	self.left.fgimg = self.fgimg
	self.left.barColor = self.barColor
	self.left.capColor = self.capColor
	self.left.turbine = self.settings.turbine
	self.left.barSize = self.left.barWidth + self.left.barSpace
	self.left.xStep = self.left.barWidth * self.left.barsInBin + self.left.barSpace * (self.left.barsInBin - 1) + self.left.binSpace
	self.left.barStep = self.left.barWidth - 1
	self.left.halfHeight = self.left.h/2
	self.left.adjustedHeight = self.left.h - self.left.yoffset_controls
	self.left.adjustedY = self.left.y - self.left.yoffset_controls
	self.left.barHeightMulti = barHeight / 31
	self.left.cap = {}
	for i = 1, numBars[1] do
		self.left.cap[i] = 0
	end
	self.left.capHeight = self.settings.capHeight
	self.left.capSpace = self.settings.capSpace
	self.left.totalCapHeight = self.left.capHeight + self.left.capSpace

	self.right = table.clone(self.left)

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

	local fgImg = params.fgImg
	local turbine = params.turbine

	local xLeft
	local yTop
	local imgXLeft

	for i = 1, #bch do
		bch[i] = bch[i] * barHeightMulti

		if bch[i] >= cch[i] then
			cch[i] = bch[i]
		elseif cch[i] > 0 then
			cch[i] = cch[i] - barHeightMulti
			if cch[i] < 0 then
				cch[i] = 0
			end
		end

		-- bar
		if bch[i] > 0 then
			nz = true
			for k = 0, barsInBin - 1 do
				xLeft = x + (k * barSize)
				if fgImg ~= nil then
					imgXLeft = xLeft - xshift
					if turbine then
						yTop = yCentre - (bch[i]/2)
						fgImg:blitClip(imgXLeft, halfHeight - (bch[i]/2),
												barWidth, bch[i],
												surface,
												xLeft, yTop)
					else
						yTop = y - bch[i] + 1
						fgImg:blitClip(imgXLeft, adjustedHeight - bch[i] + 1,
												barWidth, bch[i],
												surface,
												xLeft, yTop)

						if capHeight > 0 and cch[i] > 0 then
							yTop = y - cch[i] - totalCapHeight
							fgImg:blitClip(imgXLeft, adjustedHeight - cch[i] - totalCapHeight,
												barWidth, capHeight,
												surface,
												xLeft, yTop)
						end
					end
				else
					if turbine then
						surface:filledRectangle(
						xLeft,
						yCentre - (bch[i]/2),
						xLeft + barStep,
						yCentre + (bch[i]/2),
						barColor
						)
					else
						surface:filledRectangle(
						xLeft,
						y,
						xLeft + barStep,
						y - bch[i] + 1,
						barColor
						)
						if capHeight > 0 and cch[i] > 0 then
							surface:filledRectangle(
								xLeft,
								y - cch[i] - totalCapHeight,
								xLeft + barStep,
								y - cch[i] - capSpace,
								capColor)
						end
					end
				end
			end
		end
		x = x + xStep
	end
	return nz
end

function draw(self, surface)
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

	if self.displayResizing ~= nil then
		local d = self.displayResizing
--		d.img:blit(surface, (x + (w-d.w)/2), (y + (h-d.h)/2), d.w, d.h)
		d.c = d.c + 1
		if d.c >= d.f then
			d.c = 0
		end
		d.img:blitClip(d.c * d.w, 0, d.w, d.h, surface, (x + (w-d.w)/2), (y + (h-d.h)/2))
		local spname = visImage:getCurrentSpectrumMeterName()
		local resized = visImage:concurrentResizeSpectrumMeter(spname, w, h)
		if resized == true then
			self:_layout(self)
		end
		return
	end

	-- Avoid calling this more than once as it's not necessary
	if not self.backgroundDrawn then
		surface:filledRectangle(x, y, x + w, y + h, self.bgCol)
		self.backgroundDrawn = true
	end

	if self.bgImg ~= nil then
--		self.bgImg:blit(surface, x, y, w, h, 0, 0)
--		self.bgImg:blitClip(0, 0, w, h, surface, x, y)
--		self.bgImg:blitAlpha(surface, x, y, self.bgAlpha)
		self.bgImg:blit(surface, x, y)
	end

	local bins = { {}, {} }

	bins[1], bins[2] = vis:spectrum()

	local nz1 = _drawBins( surface, bins[1], self.left)
	local nz2 = _drawBins( surface, bins[2], self.right)

	-- simulate draw analyzer baseline only if playing,
	-- by not drawing baseline if volume is 0
	-- good enough
	if self.settings.baselineAlways or ((nz1 or nz2) and self.settings.baselineOn) then
		local baseLineHeight = self.baseLineHeight
		local halfBaseLineHeight = baseLineHeight/2
		local xSpan = self.xSpan
		if self.fgImg ~= nil then
			if self.settings.turbine then
				self.fgImg:blitClip(self.x1 - x, (h/2) - halfBaseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x1, self.yCentre - halfBaseLineHeight)
				self.fgImg:blitClip(self.x2 - x, (h/2) - halfBaseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x2, self.yCentre - halfBaseLineHeight)
			else
				self.fgImg:blitClip(self.x1 - x, h - self.yoffset_controls - baseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x1, self.y - self.yoffset_controls - baseLineHeight)
				self.fgImg:blitClip(self.x2 - x, h - self.yoffset_controls - baseLineHeight, xSpan, baseLineHeight,
									surface,
									self.x2, self.y - self.yoffset_controls - baseLineHeight)
			end
		else
			if self.settings.turbine then
				surface:filledRectangle(self.x1, self.yCentre - halfBaseLineHeight, self.x1 + xSpan ,
										self.yCentre + baseLineHeight - halfBaseLineHeight, self.barColor)
				surface:filledRectangle(self.x2, self.yCentre - halfBaseLineHeight, self.x2 + xSpan ,
										self.yCentre + baseLineHeight - halfBaseLineHeight, self.barColor)
			else
				surface:filledRectangle(self.x1, self.y - baseLineHeight - self.yoffset_controls,
										self.x1 + xSpan, self.y - self.yoffset_controls, self.barColor)
				surface:filledRectangle(self.x2, self.y - baseLineHeight - self.yoffset_controls,
										self.x2 + xSpan, self.y - self.yoffset_controls, self.barColor)
			end
		end
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

