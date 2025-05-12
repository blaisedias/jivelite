
--[[
=head1 NAME

applets.JogglerSkin.WQVGAsmallSkinMeta 

=head1 DESCRIPTION

See L<applets.WQVGAsmallSkin.WQVGAsmallSkinApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local tostring, tonumber, ipairs  = tostring, tonumber, ipairs

local oo            = require("loop.simple")
local os            = require("os")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local Framework     = require("jive.ui.Framework")
local jogglerScaler = require("applets.JogglerSkin.JogglerScaler")

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	return {
		rew = true,
		play = true,
		fwd = true,
		repeatMode = false,
		shuffleMode = false,
		volDown = true,
		volSlider = true,
		volUp = true,
	}
end

function registerApplet(self)
	if Framework:getGlobalSetting("jogglerScaleAndCustomise") == nil then
		-- default to enabling scaling and customisation
		Framework:setGlobalSetting("jogglerScaleAndCustomise", true)
	end

	self:registerService('getNowPlayingScreenButtons')
	self:registerService('setNowPlayingScreenButtons')

	jiveMain:registerSkin(self:string("JOGGLER_SKIN"), "JogglerSkin", "skin", "JogglerSkin")
	if Framework:getWmAvailable() == true then
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1024_600"), "JogglerSkin", "skin1024x600", "JogglerSkin_1024x600")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1280_400"), "JogglerSkin", "skin1280x400", "JogglerSkin_1280x400")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1280_720"), "JogglerSkin", "skin1280x720", "JogglerSkin_1280x720")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1280_800"), "JogglerSkin", "skin1280x800", "JogglerSkin_1280x800")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1366_768"), "JogglerSkin", "skin1366x768", "JogglerSkin_1366x768")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1480_320"), "JogglerSkin", "skin1480x320", "JogglerSkin_1480x320")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1600_720"), "JogglerSkin", "skin1600x720", "JogglerSkin_1600x720")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_720_1280"), "JogglerSkin", "skin720x1280", "JogglerSkin_720x1280")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1280_1024"), "JogglerSkin", "skin1280x1024", "JogglerSkin_1280x1024")
		jiveMain:registerSkin(self:string("JOGGLER_SKIN_1920_1080"), "JogglerSkin", "skin1920x1080", "JogglerSkin_1920x1080")
		local screen_width = tonumber(os.getenv('JL_SCREEN_WIDTH') or 0)
		local screen_height = tonumber(os.getenv('JL_SCREEN_HEIGHT') or 0)
		if screen_width > 300 and screen_height > 200 and screen_width/screen_height >= 1.2 then
			jiveMain:registerSkin(tostring(self:string("JOGGLER_SKIN_CUSTOM")) .. " (" .. tostring(screen_width) .. "x" .. tostring(screen_height) .. ")", "JogglerSkin", "skinCustom", "JogglerSkin_Custom")
		elseif screen_width > 0 or screen_height > 0 then
			log:warn("Custom screen size ratio (width/height) must be >= 1.2, is " .. tostring(screen_width/screen_height))
		end
	end

	local node = {
		id = 'jogglerLayout',
		iconstyle = 'hm_settings',
		node = 'screenSettings',
		text = self:string("LAYOUT"),
		windowStyle = 'text_only',
		weight = 900,
	}
	jiveMain:addNode(node)

	local scalingMenuItems = {
		{ key='textScaleFactor', titleString='TEXT_SCALING', skin='jogglerSkin', value_type='float'},
		{ key='npTextScaleFactor', titleString='NP_TEXT_SCALING', skin='jogglerSkin', value_type='float'},
		{ key='thumbnailScaleFactor', titleString='THUMBNAIL_SCALING', skin='jogglerSkin', value_type='float'},
		{ key='controlsScaleFactor', titleString='CONTROLS_SCALING', skin='jogglerSkin', value_type='float'},
		{ key='gridTextScaleFactor', titleString='GRID_TEXT_SCALING', skin='gridSkin', value_type='float'},
	}
	local npMenuItems = {
		{ key='NP_TRACK_FONT_SIZE', titleString='TRACK_FONT_SIZE', skin='jogglerSkin', value_type='integer'},
		{ key='NP_ARTISTALBUM_FONT_SIZE', titleString='ARTISTALBUM_FONT_SIZE', skin='jogglerSkin', value_type='integer'},
		{ key='NP_LINE_SPACING', titleString='LINE_SPACING', skin='jogglerSkin', value_type='float'},
		{ key='NP_TRACKLAYOUT_ALIGN', titleString='TRACKLAYOUT_ALIGN', skin='jogglerSkin', value_type='alpha'},
	}

	local weight = 10
	jiveMain:addItem(
		self:menuItem(
			'resetCustomLayout',
			'jogglerLayout',
			'RESET_LAYOUT_CUSTOMISATION',
			function(applet)
				if Framework:getGlobalSetting("jogglerScaleAndCustomise") == true then
					for _, entry in ipairs(scalingMenuItems) do
						jogglerScaler.updateJsonConfig(entry.key, entry.skin, nil)
					end
					for _, entry in ipairs(npMenuItems) do
						jogglerScaler.updateJsonConfig(entry.key, entry.skin, nil)
					end
					applet:reloadSkin()
				else
					applet:messageBox("Scaling & Customisation,\nis not enabled", 2000)
				end
			end,
			weight
		)
	)

	for _, entry in ipairs(scalingMenuItems) do
		weight = weight + 10
		jiveMain:addItem(
			self:menuItem(
				entry.key,
				'jogglerLayout',
				entry.titleString,
				function(applet)
					applet:inputLayoutValue(entry.key, entry.skin, entry.titleString, entry.value_type)
				end,
				weight
			)
		)
	end

	weight = weight + 10
	jiveMain:addItem(
		self:menuItem(
			'deleteScaledUIImages',
			'jogglerLayout',
			'DEL_SCALED_UI_IMAGES',
			function(applet)
				if Framework:getGlobalSetting("jogglerScaleAndCustomise") == true then
					jogglerScaler.deleteAllScaledUIImages()
					applet:reloadSkin()
				else
					applet:messageBox("Scaling & Customisation,\nis not enabled", 2000)
				end
			end,
			weight
		)
	)

	for _, entry in ipairs(npMenuItems) do
		weight = weight + 10
		jiveMain:addItem(
			self:menuItem(
				entry.key,
				'jogglerLayout',
				entry.titleString,
				function(applet)
					applet:inputLayoutValue(entry.key, entry.skin, entry.titleString, entry.value_type)
				end,
				weight
			)
		)
	end
end
--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

