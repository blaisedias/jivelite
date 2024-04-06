
--[[
=head1 NAME

applets.HDSkin.HDSkinMeta 

=cut
--]]
local tostring, tonumber  = tostring, tonumber

local oo            = require("loop.simple")
local os            = require("os")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local Framework     = require("jive.ui.Framework")
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {}
end

function registerApplet(self)
	if Framework:getWmAvailable() == true then
		jiveMain:registerSkin(self:string("HD_SKIN_1080"), "HDSkin", "skin_1080p", "HDSkin-1080")
		jiveMain:registerSkin(self:string("HD_SKIN_720"),  "HDSkin", "skin_720p", "HDSkin-720")
		jiveMain:registerSkin(self:string("HD_SKIN_1280_1024"),  "HDSkin", "skin_1280_1024", "HDSkin-1280-1024")
		jiveMain:registerSkin(self:string("HD_SKIN_WSVGA"),  "HDSkin", "skin_wsvga", "HDSkin-WSVGA")
		jiveMain:registerSkin(self:string("HD_SKIN_VGA"),  "HDSkin", "skin_vga", "HDSkin-VGA")
		jiveMain:registerSkin(self:string("HD_SKIN_1600_720"),  "HDSkin", "skin_1600_720", "HDSkin-1600-720")
		local screen_width = tonumber(os.getenv('JL_SCREEN_WIDTH') or 0)
		local screen_height = tonumber(os.getenv('JL_SCREEN_HEIGHT') or 0)
		if screen_width > 0 or screen_height > 0 then
			jiveMain:registerSkin(tostring(self:string("HD_SKIN")) .. " (" .. tostring(screen_width) .. "x" .. tostring(screen_height) .. ")", "HDSkin", "skin_custom", "HDSkin")
		end
	else
		jiveMain:registerSkin(self:string("HD_SKIN"), "HDSkin", "skin_hd", "HDSkin")
	end
end


