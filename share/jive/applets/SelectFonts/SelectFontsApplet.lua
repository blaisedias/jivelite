
--[[
=head1 NAME

applets.SelectFonts.SelectFontsApplet - An applet to select different fonts

=head1 DESCRIPTION

This applet allows the fonts to be selected.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SelectFontsApplet overrides the following methods:

=cut
--]]


-- stuff we use
local pairs, type = pairs, type

local table           = require("table")

local oo              = require("loop.simple")

local Applet          = require("jive.Applet")
local RadioButton     = require("jive.ui.RadioButton")
local RadioGroup      = require("jive.ui.RadioGroup")
local Checkbox        = require("jive.ui.Checkbox")
local System          = require("jive.System")
local debug           = require("jive.utils.debug")
local log			  = require("jive.utils.log").logger("applet.SelectFonts")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local Font            = require("jive.ui.Font")
local Timer           = require("jive.ui.Timer")
local JiveMain        = jiveMain
local appletManager   = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local fontsdb = {
	FreeSans={regular="FreeSans",bold="FreeSansBold"},
	Laila={ regular="Laila/Laila-Regular", bold="Laila/Laila-SemiBold", },
	Mina={ regular="Mina/Mina-Regular", bold="Mina/Mina-Bold", },
	BenchNine={ regular="BenchNine/BenchNine-Regular", bold="BenchNine/BenchNine-Bold", },
	Dongle={ regular="Dongle/Dongle-Regular", bold="Dongle/Dongle-Bold", },
	Dosis={ regular="Dosis/Dosis-Light", bold="Dosis/Dosis-SemiBold", },
	GemunuLibre={ regular="GemunuLibre/GemunuLibre-Regular", bold="GemunuLibre/GemunuLibre-SemiBold", },
	Genos={ regular="Genos/Genos-Regular", bold="Genos/Genos-SemiBold", },
	Glory={ regular="Glory/Glory-Regular", bold="Glory/Glory-SemiBold", },
	K2D={ regular="K2D/K2D-Regular", bold="K2D/K2D-SemiBold", },
	MontserratItalic={
        regular="Montserrat/static/Montserrat-Italic",
        bold="Montserrat/static/Montserrat-SemiBoldItalic",
    },
	MontserratMedium={ regular="Montserrat/static/Montserrat-Medium", bold="Montserrat/static/Montserrat-SemiBold", },
	MontserratRegular={ regular="Montserrat/static/Montserrat-Regular", bold="Montserrat/static/Montserrat-Bold", },
--	MontserratVariable={
--        regular="Montserrat/Montserrat-VariableFont_wght",
--        bold="Montserrat/Montserrat-Italic-VariableFont_wght"
 --   },
	MuseoModerno={ regular="MuseoModerno/MuseoModerno-Regular", bold="MuseoModerno/MuseoModerno-SemiBold", },
	Nunito={ regular="Nunito/Nunito-Regular", bold="Nunito/Nunito-Bold", },
	Orbitron={ regular="Orbitron/Orbitron-Regular", bold="Orbitron/Orbitron-Bold", },
	Rajdhani={ regular="Rajdhani/Rajdhani-Regular", bold="Rajdhani/Rajdhani-SemiBold", },
	SmoochSans={ regular="Smooch Sans/SmoochSans-Regular", bold="Smooch Sans/SmoochSans-SemiBold", },
	Yanone_Kafeesatz={
        regular="Yanone_Kafeesatz/YanoneKaffeesatz-Regular",
        bold="Yanone_Kafeesatz/YanoneKaffeesatz-SemiBold",
    },
	Antonio={ regular="Antonio/static/Antonio-Regular", bold="Antonio/static/Antonio-SemiBold", },
	Oswald={ regular="Oswald/static/Oswald-Regular", bold="Oswald/static/Oswald-SemiBold", },
    Roboto= { regular="Roboto/static/Roboto-Regular", bold="Roboto/static/Roboto-SemiBold" },
    RobotoItalic= { regular="Roboto/static/Roboto-Italic", bold="Roboto/static/Roboto-SemiBoldItalic" },
    RobotoSemiCondensed= { regular="Roboto/static/Roboto_SemiCondensed-Regular", bold="Roboto/static/Roboto_SemiCondensed-SemiBold" },
    RobotoCondensed= { regular="Roboto/static/Roboto_Condensed-Regular", bold="Roboto/static/Roboto_Condensed-SemiBold" },
}

function selectFontsEntryPoint(self, menuItem)
	return selectFonts(self, menuItem.text)
end


function selectFontStartup(self, setupNext)
	return selectFonts(self, self:string("SELECT_FONTS"))
end


function selectFonts(self, title)
	local window = Window("text_list", title, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local group = RadioGroup()
	local current = self:getSettings()['name']
	log:debug("current ", current)

	-- add skins
	for name, v in pairs(fontsdb) do
		menu:addItem({
			text = name,
			style = 'item_choice',
			check = RadioButton(
				"radio", 
				group, 
				function()
					local settings = self:getSettings()
					settings['regular'] = v['regular']
					settings['bold'] = v['bold']
					settings['name'] = name
					log:debug("font ", name, " regular:", v['regular'], " bold:", v['bold'])
					self:storeSettings()
					Font:setupFonts()
					JiveMain:reloadSkin()
				end,
				name==current
			)
		})
	end

	window:addWidget(menu)

	window:addListener(EVENT_WINDOW_POP,
		function()
			if self.changed then
				self:storeSettings()
			end
			if setupNext then
				setupNext()
			end
		end
	)

	self:tieAndShowWindow(window)
	return window
end

--[[

=head1 LICENSE

Copyright 2010 Logitech, 2024 Blaise Dias. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

