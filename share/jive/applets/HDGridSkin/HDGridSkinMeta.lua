
--[[
=head1 NAME

applets.HDGridSkin.HDGridSkinMeta 

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
			if skin_width < 1920 or skin_height < 1080 then
				return
			end
	end
	jiveMain:registerSkin(self:string("HD_GRID_SKIN_1080"), "HDGridSkin", "skin_1080p", "HDGridSkin-1080")
end


