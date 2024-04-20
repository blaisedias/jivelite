
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
local visImage      = require("jive.visImage")
--local os            = require("os")

--local arg, ipairs, string = arg, ipairs, string

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	return {
		cacheEnabled=false,
		randomSequence=false,
		spectrum={
			baselineOn=true,
			baselineAlways=false,
			turbine=false,
			channelFlip={values={0,1,},name="Low Freq > High Freq, High Freq > Low Freq",},
			backlitAlpha=80,
			barsFormat={values={barsInBin=1,barSpace=0,barWidth=4,binSpace=2,},name="1-4-0-2",},
			capsOn=true,
		},
		vuMeterSelection={["RS-M250"]=true,},
		spectrumMeterSelection={
			["mc-White translucent"]={spType="colour",capColor=3503345919,barColor=3503345824,enabled=true,},
		},
	}
end

function registerApplet(self)
	-- early setup of visualiser image module settings
	local settings = self:getSettings()
	visImage:setVisSettings(settings)

	local node = { id = 'visualiserSettings', iconStyle = 'hm_settings', node = 'settings', text = 'Visualiser', windowStyle = 'text_only'  }
	jiveMain:addNode(node)

-- TODO:
--	jiveMain:addItem(
--		self:menuItem(
--			'appletVuMeterSelection',
--			'visualiserSettings',
--			'SELECT_VUMETER',
--			function(applet, ...)
--				applet:selectVuMeters(...)
--			end,
--            10
--		)
--	)
--	jiveMain:addItem(
--		self:menuItem(
--			'appletSpectrumMeterSelection',
--			'visualiserSettings',
--			'SELECT_SPECTRUM',
--			function(applet, ...)
--				applet:selectSpectrumMeters(...)
--			end,
--            20
--		)
--	)

	node = { id = 'visualiserSpectrumSettings', iconStyle = 'hm_settings', node = 'visualiserSettings', text = 'Spectrum Meter Settings', windowStyle = 'text_only', weight=30  }
	jiveMain:addNode(node)


	jiveMain:addItem(
		self:menuItem(
			'appletVisualiserSettings',
			'visualiserSettings',
			'Resize Images',
			function(applet, ...)
				applet:imagesMenu(...)
			end,
            100
		)
	)


	jiveMain:addItem(
		self:menuItem(
			'appletSpectrumBarSettings',
			'visualiserSpectrumSettings',
			'SPECTRUM_BARS_FORMAT',
			function(applet, ...)
				applet:selectSpectrumBarsFormat(...)
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletSpectrumChannelFlipSettings',
			'visualiserSpectrumSettings',
			'SPECTRUM_CHANNEL_FLIP',
			function(applet, ...)
				applet:selectSpectrumChannelFlip(...)
			end
		)
	)


end

function configureApplet(self)
	-- make resident applet
	appletManager:loadApplet("Visualiser")
end

