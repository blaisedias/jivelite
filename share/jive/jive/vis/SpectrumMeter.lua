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
--local type	= type
local string        = require("jive.utils.string")
local sep = 6

module(...)
oo.class(_M, Icon)


function __init(self, style, windowStyle)
	local obj = oo.rawnew(self, Icon(style))

	obj.val = { 0, 0 }
	obj.nplarge = false
	if windowStyle == "nowplaying_large_spectrum" then
		obj.nplarge = true
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
	self.barsInBin = {}
	self.barWidth = {}
	self.barSpace = {}
	self.binSpace = {}
	self.clipSubbands = {}
	self.counter = FRAME_RATE * visImage.getVisualiserChangeOnTimerValue()
	self.countDown = self.counter ~= 0

	self.isMono =  self:styleValue("isMono")

	self.fgImg, self.bgImg, self.bgAlpha, self.barColor, self.capColor = visImage:getSpectrum(w, h, self.barColor, self.capColor)
	log:info('** barColor=', string.format("0x%x", self.barColor), " capColor=", string.format("0x%x",self.capColor))
	self.settings = visImage:getSpectrumMeterSettings(self:styleValue("capHeight"), self:styleValue("capSpace"))

	self.clipSubbands = self:styleValue("clipSubbands")
	self.barsInBin = {self.settings.barsFormat.barsInBin, self.settings.barsFormat.barsInBin}
	self.barWidth = {self.settings.barsFormat.barWidth, self.settings.barsFormat.barWidth}
	self.barSpace = {self.settings.barsFormat.barSpace, self.settings.barsFormat.barSpace}
	self.binSpace = {self.settings.barsFormat.binSpace, self.settings.barsFormat.binSpace}

	self.backgroundDrawn = false;

	if self.barsInBin[1] < 1 then
		self.barsInBin[1] = 1
	end
	if self.barsInBin[2] < 1 then
		self.barsInBin[2] = 1
	end
	if self.barWidth[1] < 1 then
		self.barWidth[1] = 1
	end
	if self.barWidth[2] < 1 then
		self.barWidth[2] = 1
	end

	local barSize = {}

	barSize[1] = self.barWidth[1] * self.barsInBin[1] + self.barSpace[1] * (self.barsInBin[1] - 1) + self.binSpace[1]
	barSize[2] = self.barWidth[2] * self.barsInBin[2] + self.barSpace[2] * (self.barsInBin[2] - 1) + self.binSpace[2]

	self.channelWidth[1] = ((w - l - r) / 2) - (sep - self.binSpace[1])
	self.channelWidth[2] = ((w - l - r) / 2) - (sep - self.binSpace[2])

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

	local barHeight = {}

	barHeight[1] = h - t - b - self.settings.capHeight[1] - self.settings.capSpace[1]
	barHeight[2] = h - t - b - self.settings.capHeight[2] - self.settings.capSpace[2]

	-- max bin value from C code is 31
	self.barHeightMulti = {}
	self.barHeightMulti[1] = barHeight[1] / 31
	self.barHeightMulti[2] = barHeight[2] / 31

	self.xshift = x + l
	self.x1 = x + l + self.channelWidth[1] - numBars[1] * barSize[1] + 2
	self.x2 = x + l + self.channelWidth[2] + self.binSpace[2] + (sep - self.binSpace[1]) + (sep - self.binSpace[2])
	self.xSpan =  numBars[1] * barSize[1] - self.binSpace[1] - 1

	-- pre calculate base line height
	self.blH = math.min(math.ceil(self.barHeightMulti[1] * 0.2), 2)
	self.halfblH = math.ceil(self.blH / 2)

	log:debug("** x: " .. x .. " l: " .. l)
	log:debug("** x1: " .. self.x1 .. " x2: " .. self.x2)
	log:debug("** w: " .. w .. " l: " .. l, " r:", r)

	self.y = y + h - b
	self.h = h
	self.yCT = self.y - (self.h/2)
	self.fgimg_yoffset = 0
	if self.nplarge then
		self.y = y + h
		self.yCT = self.y - (self.h/2)
		self.fgimg_yoffset = t
	end

	self.cap = { {}, {} }
	for i = 1, numBars[1] do
		self.cap[1][i] = 0
	end

	for i = 1, numBars[2] do
		self.cap[2][i] = 0
	end

end

local function _drawBins(self, surface, bins, ch, x, y_in, barsInBin, barWidth, barSpace, binSpace, barHeightMulti, capHeight, capSpace)
	local bch = bins[ch]
	local cch = self.cap[ch]
	local barSize = barWidth + barSpace
	local hh = self.h
	local xshift = self.xshift
	local y = y_in - self.fgimg_yoffset
	local nz = false

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
				if self.fgImg ~= nil then
					local xLeft = x + (k * barSize)
					if self.settings.turbine then
						local yTop = self.yCT - (bch[i]/2)
						self.fgImg:blitClip(xLeft - xshift, (hh/2) - (bch[i]/2), barWidth, bch[i], surface, xLeft, yTop)
					else
						local yTop = y - bch[i] + 1
						self.fgImg:blitClip(xLeft - xshift, hh - self.fgimg_yoffset - bch[i] + 1, barWidth, bch[i], surface, xLeft, yTop)

						if capHeight > 0 and cch[i] > 0 then
							yTop = y - cch[i] - capHeight - capSpace
							self.fgImg:blitClip(xLeft - xshift, hh - self.fgimg_yoffset - cch[i] - capHeight - capSpace ,
												barWidth, capHeight, surface,
												xLeft, yTop)
						end
					end
				else
					if self.settings.turbine then
						surface:filledRectangle(
						x + (k * barSize),
						self.yCT - (bch[i]/2),
						x + (barWidth - 1) + (k * barSize),
						self.yCT + (bch[i]/2),
						self.barColor
						)
					else
						surface:filledRectangle(
						x + (k * barSize),
						y,
						x + (barWidth - 1) + (k * barSize),
						y - bch[i] + 1,
						self.barColor
						)
						if capHeight > 0 and cch[i] > 0 then
							surface:filledRectangle(
								x + (k * barSize),
								y - cch[i] - capHeight - capSpace,
								x + (barWidth - 1) + (k * barSize),
								y - cch[i] - capSpace,
								self.capColor)
						end
					end
				end
			end
		end
		x = x + barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace
	end
	return nz
end

function draw(self, surface)
-- Black background instead of image
--	self.bgImg:blit(surface, self:getBounds())
	local x, y, w, h = self:getBounds()

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

	local nz1 = _drawBins(
		self, surface, bins, 1, self.x1, self.y, self.barsInBin[1],
		self.barWidth[1], self.barSpace[1], self.binSpace[1],
		self.barHeightMulti[1], self.settings.capHeight[1], self.settings.capSpace[1]
	)
	local nz2 = _drawBins(
		self, surface, bins, 2, self.x2, self.y, self.barsInBin[2],
		self.barWidth[2], self.barSpace[2], self.binSpace[2],
		self.barHeightMulti[2], self.settings.capHeight[2], self.settings.capSpace[2]
	)

	-- simulate draw analyzer baseline only if playing,
	-- by not drawing baseline if volume is 0
	-- good enough
	if self.settings.baselineAlways or ((nz1 or nz2) and self.settings.baselineOn) then
		if self.fgImg ~= nil then
			if self.settings.turbine then
				self.fgImg:blitClip(self.x1 - x, (h/2) - self.halfblH, self.xSpan, self.blH,
									surface,
									self.x1, self.yCT - self.halfblH)
				self.fgImg:blitClip(self.x2 - x, (h/2) - self.halfblH, self.xSpan, self.blH,
									surface,
									self.x2, self.yCT - self.halfblH)
			else
				self.fgImg:blitClip(self.x1 - x, h - self.fgimg_yoffset - self.blH, self.xSpan, self.blH,
									surface,
									self.x1, self.y - self.fgimg_yoffset - self.blH)
				self.fgImg:blitClip(self.x2 - x, h - self.fgimg_yoffset - self.blH, self.xSpan, self.blH,
									surface,
									self.x2, self.y - self.fgimg_yoffset - self.blH)
			end
		else
			if self.settings.turbine then
				surface:filledRectangle(self.x1, self.yCT - self.halfblH, self.x1 + self.xSpan ,
										self.yCT + self.blH - self.halfblH, self.barColor)
				surface:filledRectangle(self.x2, self.yCT - self.halfblH, self.x2 + self.xSpan ,
										self.yCT + self.blH - self.halfblH, self.barColor)
			else
				surface:filledRectangle(self.x1, self.y - self.blH - self.fgimg_yoffset,
										self.x1 + self.xSpan, self.y - self.fgimg_yoffset, self.barColor)
				surface:filledRectangle(self.x2, self.y - self.blH - self.fgimg_yoffset,
										self.x2 + self.xSpan, self.y - self.fgimg_yoffset, self.barColor)
			end
		end
	end
	if self.countDown then
		self.counter = self.counter - 1
		if self.counter < 1 then
			visImage:spChange('force', 'force')
			self:_layout()
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

