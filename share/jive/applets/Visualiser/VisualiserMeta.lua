
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
local pairs         = pairs
local table         = require("table")

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
        visuChangeOnTrackChange=true,
        visuChangeOnNpViewChange=false,
        visuChangeOnTimer=0,
        vuMeterSelection={},
        spectrumMeterSelection={},
        spectrum={
            baselineOn=false,
            baselineAlways=true,
            turbine=false,
            channelFlip="LHHL",
            backlitAlpha=80,
            capsOn=true,
            barsFormat="2-1-3-6",
            barFormats  = {
                ["2-1-3-6"]= {barsInBin=2, barWidth=1, barSpace=3, binSpace=6},
                ["2-2-3-4"]= {barsInBin=2, barWidth=2, barSpace=3, binSpace=4},
                ["2-3-3-2"]= {barsInBin=2, barWidth=3, barSpace=3, binSpace=2},
                ["2-4-1-4"]= {barsInBin=2, barWidth=4, barSpace=1, binSpace=4},
                ["1-10-0-10"]= {barsInBin=1, barWidth=10, barSpace=0, binSpace=10},
                ["2-03-2-10"]= {barsInBin=2, barWidth=3, barSpace=2, binSpace=10},
                ["2-04-3-06"]= {barsInBin=2, barWidth=4, barSpace=3, binSpace=6},
                ["3-03-2-05"]= {barsInBin=3, barWidth=3, barSpace=2, binSpace=5},
                ["4-02-2-04"]= {barsInBin=4, barWidth=2, barSpace=2, binSpace=4},
                ["1-15-0-5"]= {barsInBin=1, barWidth=15, barSpace=0, binSpace=5},
                ["1-18-0-2"]= {barsInBin=1, barWidth=18, barSpace=0, binSpace=2},
                ["2-07-2-5"]= {barsInBin=2, barWidth=7, barSpace=2, binSpace=5},
                ["2-05-4-5"]= {barsInBin=2, barWidth=5, barSpace=4, binSpace=5},
                ["3-03-2-5"]= {barsInBin=3, barWidth=3, barSpace=2, binSpace=5},
                ["1-10-0-5"]= {barsInBin=1, barWidth=10, barSpace=0, binSpace=5},
                ["1-13-0-2"]= {barsInBin=1, barWidth=13, barSpace=0, binSpace=2},
                ["1-4-0-6"]= {barsInBin=1, barWidth=4, barSpace=0, binSpace=6},
                ["1-6-0-4"]= {barsInBin=1, barWidth=6, barSpace=0, binSpace=4},
                ["1-8-0-2"]= {barsInBin=1, barWidth=8, barSpace=0, binSpace=2},
                ["1-5-0-5"]= {barsInBin=1, barWidth=5, barSpace=0, binSpace=5},
                ["1-5-0-3"]= {barsInBin=1, barWidth=5, barSpace=0, binSpace=3},
                ["1-4-0-4"]= {barsInBin=1, barWidth=4, barSpace=0, binSpace=4},
                ["1-4-0-3"]= {barsInBin=1, barWidth=4, barSpace=0, binSpace=3},
                ["1-5-0-2"]= {barsInBin=1, barWidth=5, barSpace=0, binSpace=2},
                ["2-2-1-2"]= {barsInBin=2, barWidth=2, barSpace=1, binSpace=2},
                ["1-4-0-2"]= {barsInBin=1, barWidth=4, barSpace=0, binSpace=2},
                ["1-3-0-3"]= {barsInBin=1, barWidth=3, barSpace=0, binSpace=3},
                ["1-3-0-2"]= {barsInBin=1, barWidth=3, barSpace=0, binSpace=2},
                ["2-1-1-2"]= {barsInBin=2, barWidth=1, barSpace=1, binSpace=2},
                ["1-2-0-2"]= {barsInBin=1, barWidth=2, barSpace=0, binSpace=2},
                ["1-3-0-1"]= {barsInBin=1, barWidth=3, barSpace=0, binSpace=1},
                ["1-2-0-1"]= {barsInBin=1, barWidth=2, barSpace=0, binSpace=1},
                ["1-1-1-1"]= {barsInBin=1, barWidth=1, barSpace=0, binSpace=1},
            },
        },
    }
end

function registerApplet(self)
    -- early setup of visualiser image module settings
    local settings = self:getSettings()
    visImage:setVisSettings(settings)
    local tmp = visImage:getVuMeterList()
    local k,v

    for k, v in pairs(tmp) do
        settings.vuMeterSelection[v.name] = v.enabled
    end
    tmp = visImage:getSpectrumMeterList()
    for k, v in pairs(tmp) do
        settings.spectrumMeterSelection[v.name] = v.enabled
    end

    self:storeSettings()

    local node = { id = 'visualiserSettings', iconStyle = 'hm_settings', node = 'settings', text = 'Visualiser', windowStyle = 'text_only'  }
    jiveMain:addNode(node)

    jiveMain:addItem(
        self:menuItem(
            'appletVuMeterSelection',
            'visualiserSettings',
            'SELECT_VUMETER',
            function(applet, ...)
                applet:selectVuMeters(...)
            end,
            10
        )
    )

    jiveMain:addItem(
        self:menuItem(
            'appletSpectrumMeterSelection',
            'visualiserSettings',
            'SELECT_SPECTRUM',
            function(applet, ...)
                applet:selectSpectrumMeters(...)
            end,
            20
        )
    )

    node = { id = 'visualiserSpectrumSettings', iconStyle = 'hm_settings', node = 'visualiserSettings', text = 'Spectrum Meter Settings', windowStyle = 'text_only', weight=30  }
    jiveMain:addNode(node)


    jiveMain:addItem(
        self:menuItem(
            'appletVisualiserSettings',
            'visualiserSettings',
            'RESIZE_IMAGES',
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

