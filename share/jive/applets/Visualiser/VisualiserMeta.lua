
--[[
=head1 NAME

applets.Visualiser.VisualiserMeta - Visualiser meta-info

=head1 DESCRIPTION

See L<applets.Visualiser.VisualiserApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

 (c) Blaise Dias, 2024

=cut
--]]

--local bit = bit

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Framework     = require("jive.ui.Framework")

local appletManager = appletManager
local jiveMain      = jiveMain
--local Checkbox      = require("jive.ui.Checkbox")
--local visImage      = require("jive.visImage")
--local os            = require("os")

--local arg, ipairs, string = arg, ipairs, string

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(self)
end

function configureApplet(self)

--	self.vic_checkbox = Checkbox("checkbox", function(applet, checked)
--		visImage:setCacheEnabled(checked)
--        local popup = jive.ui.Popup("waiting_popup", "Boo1")
--        popup:show()
--        os.sleep(5)
--        popup:hide()
--	end)
--	jiveMain:addItem({
--		id = "vic",
--		node = "settings",
--		text = self:string('VISUALISER_IMAGE_CACHING'),
--		style = 'item_choice',
--		check = self.vic_checkbox,
--	})
--	self.vic_checkbox:setSelected(visImage:getCacheEnabled())
    local icon = 'hm_settings'

	-- we only register the menu here, as registerApplet is being called before the skin is initialized
    jiveMain:addItem(
    	self:menuItem(
    		'VisualiserApplet',
    		'settings',
    		'Visualiser',
    		function(applet, ...) 
    			applet:menu(...)
    		end,
    		100,
    		nil,
		icon
    	)
    )
end
