
--[[
=head1 NAME

jive.ui.Font - A truetype font.

=head1 DESCRIPTION

A font object. Fonts are used for drawing text on L<jive.ui.Surface>'s.

=head1 SYNOPSIS

 -- Load a 12pt font
 local font = jive.ui.Font:load("FreeSans.ttf", 12)

 -- Measure font width and height
 local w = font:width("A string")
 local h = font:height()

=head1 METHODS

=head2 jive.ui.Font:load(name, size)

Load the font. I<name> is the filename for the font, if this is a relative filename the lua path is searched for the font file. I<size> is the size of the font.

=head2 jive.ui.Font:width(str)

Returns the number of pixels used to render I<str> in this font.

=head2 jive.ui.Font:height()

Returns the height of the font.

=head2 jive.ui.Font:ascend()

Return the ascend height of the font.

=cut
--]]


-- C implementation

local oo = require("loop.base")
local math             = require("math")
local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("jivelite.ui")
local appletManager    = require("jive.AppletManager")

module(..., oo.class)

local fontpath = "fonts/"
local FONT_NAME = "FreeSans"
local BOLD_FONT_NAME = "FreeSansBold"

function setupFonts(self)
	-- load the font settings directly
	local fonts = appletManager:loadFontSettings()
	if fonts ~= nil then
		log:info("got font settings: regular:", fonts['regular'], " bold:" , fonts['bold'])
		if fonts['regular'] ~= nil then
			FONT_NAME = fonts['regular']
		end

		if fonts['bold'] ~= nil then
			BOLD_FONT_NAME = fonts['bold']
		end
	end
	log:info("fonts: regular:", FONT_NAME, " bold:" , BOLD_FONT_NAME)
	-- setup the default font for C code
	self:default(fontpath .. FONT_NAME .. ".ttf")
end

function regularFont(self, fontSize)
	return self:load(fontpath .. FONT_NAME .. ".ttf", fontSize)
end

function boldFont(self, fontSize)
	return self:load(fontpath .. BOLD_FONT_NAME .. ".ttf", fontSize)
end
--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
