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
local type	= type

module(...)
oo.class(_M, Icon)


function __init(self, style)
	local obj = oo.rawnew(self, Icon(style))

	obj.val = { 0, 0 }

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

	self.gradientColours = self:styleValue("gradientColours", {self.barColor})
	self.useGradient = #self.gradientColours - 1
	self.useVisImage = self:styleValue("useVisImage", false)
	self.spType = self:styleValue("spType")
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	-- When used in NP screen _layout gets called with strange values
	if (w <= 0) and (h <= 0) then
		return
	end

	self.capHeight = {}
	self.capSpace = {}

	self.channelWidth = {}
	self.channelFlipped = {}
	self.barsInBin = {}
	self.barWidth = {}
	self.barSpace = {}
	self.binSpace = {}
	self.clipSubbands = {}

	self.isMono =  self:styleValue("isMono")

	if self.useVisImage then
		self.fgImg, self.bgImg, self.bgAlpha, barColour, capColour = visImage:getSpectrum(w, h, self.spType)
		log:debug("barColour=", barColour, " ", type(barColour), " capColour=", capColour, " ", type(capColour))
		if type(barColour) == "number" then
			self.barColor = barColour
		end
		if type(capColour) == "number" then
			self.capColor = capColour
		end
	end

--	self.capHeight = self:styleValue("capHeight")
--	self.capSpace = self:styleValue("capSpace")
	self.capHeight, self.capSpace = visImage:getCapsValues(self:styleValue("capHeight"), self:styleValue("capSpace"))
--	self.channelFlipped = self:styleValue("channelFlipped")
	self.channelFlipped = visImage:getChannelFlipValues()
	self.clipSubbands = self:styleValue("clipSubbands")
	-- selectable from ui
	local barsFormat = visImage:getBarsFormat()
--	if barsFormat.name == " default" then
--		self.barsInBin = self:styleValue("barsInBin")
--		self.barWidth = self:styleValue("barWidth")
--		self.barSpace = self:styleValue("barSpace")
--		self.binSpace = self:styleValue("binSpace")
--	else
		self.barsInBin = {barsFormat.values.barsInBin, barsFormat.values.barsInBin}
		self.barWidth = {barsFormat.values.barWidth, barsFormat.values.barWidth}
		self.barSpace = {barsFormat.values.barSpace, barsFormat.values.barSpace}
		self.binSpace = {barsFormat.values.binSpace, barsFormat.values.binSpace}
--	end
	
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

	sep = 6
	self.channelWidth[1] = ((w - l - r) / 2) - (sep - self.binSpace[1])
	self.channelWidth[2] = ((w - l - r) / 2) - (sep - self.binSpace[2])

	local numBars = {}

	numBars = vis:spectrum_init(
		self.isMono,

		self.channelWidth[1],
		self.channelFlipped[1],
		barSize[1],
		self.clipSubbands[1],

		self.channelWidth[2],
		self.channelFlipped[2],
		barSize[2],
		self.clipSubbands[2]
	)

	log:debug("-----------------------------------------------------")
	log:debug("** 1: " .. numBars[1] .. " 2: " .. numBars[2])

	local barHeight = {}

	barHeight[1] = h - t - b - self.capHeight[1] - self.capSpace[1]
	barHeight[2] = h - t - b - self.capHeight[2] - self.capSpace[2]


	-- max bin value from C code is 31
	self.barHeightMulti = {}
	self.barHeightMulti[1] = barHeight[1] / 31
	self.barHeightMulti[2] = barHeight[2] / 31

	self.xshift = x + l
	self.x1 = x + l + self.channelWidth[1] - numBars[1] * barSize[1] + 2 
	self.x2 = x + l + self.channelWidth[2] + self.binSpace[2] + (sep - self.binSpace[1]) + (sep - self.binSpace[2])
	log:debug("** x: " .. x .. " l: " .. l)
	log:debug("** x1: " .. self.x1 .. " x2: " .. self.x2)
	log:debug("** w: " .. w .. " l: " .. l, " r:", r)
	log:debug("** cw1: " .. self.channelWidth[1] .. " nB1xbS: " .. numBars[1] * barSize[1])

	self.y = y + h - b
	-- gradient table y step
	self.deltaY = math.floor(h / (#self.gradientColours - 1))
	log:debug("** y: " .. self.y .. " deltaY: " .. self.deltaY .. " h:" .. h)

	self.cap = { {}, {} }
	for i = 1, numBars[1] do
		self.cap[1][i] = 0
	end

	for i = 1, numBars[2] do
		self.cap[2][i] = 0
	end

end


function draw(self, surface)
-- Black background instead of image
--	self.bgImg:blit(surface, self:getBounds())

	-- Avoid calling this more than once as it's not necessary
	if not self.backgroundDrawn then
		local x, y, w, h = self:getBounds()
		surface:filledRectangle(x, y, x + w, y + h, self.bgCol)
		self.backgroundDrawn = true
	end
	if self.bgImg ~= nil then
		local x, y, w, h = self:getBounds()
--		self.bgImg:blit(surface, x, y, w, h, 0, 0)
--		self.bgImg:blitClip(0, 0, w, h, surface, x, y)
--		self.bgImg:blitAlpha(surface, x, y, self.bgAlpha)
		self.bgImg:blit(surface, x, y)
	end

	local bins = { {}, {} }

	bins[1], bins[2] = vis:spectrum()

	_drawBins(
		self, surface, bins, 1, self.x1, self.y, self.barsInBin[1],
		self.barWidth[1], self.barSpace[1], self.binSpace[1],
		self.barHeightMulti[1], self.capHeight[1], self.capSpace[1]
	)
	_drawBins(
		self, surface, bins, 2, self.x2, self.y, self.barsInBin[2],
		self.barWidth[2], self.barSpace[2], self.binSpace[2],
		self.barHeightMulti[2], self.capHeight[2], self.capSpace[2]
	)

end



function _drawBins(self, surface, bins, ch, x, y, barsInBin, barWidth, barSpace, binSpace, barHeightMulti, capHeight, capSpace)
	local bch = bins[ch]
	local cch = self.cap[ch]
	local barSize = barWidth + barSpace
	local xx, yy, ww, hh = self:getBounds()
	local xshift = self.xshift

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
			for k = 0, barsInBin - 1 do
				if self.fgImg ~= nil then
					local yBottom = y
					local yTop = y - bch[i] + 1
					local xLeft = x + (k * barSize)
					local xRight = xLeft + (barWidth - 1)
					self.fgImg:blitClip(xLeft - xshift, hh - bch[i] + 1, barWidth, hh, surface, xLeft, yTop)

					if capHeight > 0 and cch[i] > 0 then
						ytop = y - cch[i] - capHeight - capSpace
						self.fgImg:blitClip(xLeft - xshift, hh - cch[i] - capHeight - capSpace , barWidth, capHeight, surface, xLeft, ytop)
					end

				elseif self.useGradient > 0 then
					local yEndValue = y - bch[i] + 1
					local xLeft = x + (k * barSize)
					local xRight = xLeft + (barWidth - 1)

					local yBottom = y
					local yTop = 0

					for iColor = 1, #self.gradientColours do
						yTop = yBottom - self.deltaY
						if yTop < yEndValue then
							yTop = yEndValue
						end
						surface:filledRectangle(xLeft, yTop, xRight, yBottom, self.gradientColours[iColor])
						yBottom = yBottom - self.deltaY
						if yBottom <= yEndValue then
							break
						end
					end
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
		x = x + barWidth * barsInBin + barSpace * (barsInBin - 1) + binSpace
	end
end
--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

Copyright 2023  additions: Blaise Dias 
=cut
--]]

