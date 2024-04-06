
--[[
=head1 NAME

applets.WQVGAsmallSkin.WQVGAsmallSkinMeta 

=head1 DESCRIPTION

See L<applets.WQVGAsmallSkin.WQVGAsmallSkinApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local Framework     = require("jive.ui.Framework")


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {}
end

function registerApplet(self)
	if Framework:getWmAvailable() == false then
			skin_width, skin_height = Framework:getDisplaySize()
			if skin_width >= 800 and skin_height >= 480 then
				return
			end
	end
	jiveMain:registerSkin(self:string("WQVGA_SMALL_SKIN"), "WQVGAsmallSkin", "skin")
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

