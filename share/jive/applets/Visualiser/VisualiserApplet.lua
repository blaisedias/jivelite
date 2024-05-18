local tostring          = tostring
local tonumber          = tonumber
local pairs             = pairs
local ipairs            = ipairs

local table             = require("table")
local string            = require("string")
local math              = require("math")
local os                = require("os")
local io                = require("io")
local oo                = require("loop.simple")
local Event             = require("jive.ui.Event")
local Icon              = require("jive.ui.Icon")
local Label             = require("jive.ui.Label")
local Popup             = require("jive.ui.Popup")
local SimpleMenu        = require("jive.ui.SimpleMenu")
local Window            = require("jive.ui.Window")
local Slider            = require("jive.ui.Slider")
local Textarea          = require("jive.ui.Textarea")
local Group             = require("jive.ui.Group")
local Framework         = require("jive.ui.Framework")
local Checkbox          = require("jive.ui.Checkbox")
local RadioButton       = require("jive.ui.RadioButton")
local RadioGroup        = require("jive.ui.RadioGroup")
local Choice            = require("jive.ui.Choice")
local Textinput         = require("jive.ui.Textinput")
local Keyboard          = require("jive.ui.Keyboard")
local visImage          = require("jive.visImage")
local log               = require("jive.utils.log").logger("applet.Visualiser")

local debug             = require("jive.utils.debug")

local Applet            = require("jive.Applet")

local appletManager     = appletManager
local jiveMain      = jiveMain

module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
    local settings = self:getSettings()

    jiveMain:addItem({
        id = "vic",
        node = 'visualiserSettings',
        text = self:string("VISUALISER_CACHE_IMAGE_RAM"),
        style = 'item_choice',
        weight = 50,
        check = Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.cacheEnabled = checked
            self:storeSettings()
            end,
            settings.cacheEnabled)
    })

    jiveMain:addItem({
        id = "viseqrand",
        node = 'visualiserSettings',
        text = self:string("VISUALISER_RANDOMISE_SEQUENCE"),
        style = 'item_choice',
        weight = 40,
        check =  Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.randomSequence = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.randomSequence)
    })

    jiveMain:addItem({
        id = "visuChangeOnTrackChange",
        node = 'visualiserSettings',
        text = self:string("VISU_CHANGE_ON_TRACK_CHANGE"),
        style = 'item_choice',
        weight = 41,
        check =  Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.visuChangeOnTrackChange = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.visuChangeOnTrackChange)
    })

    jiveMain:addItem({
        id = "visuChangeOnNpViewChange",
        node = 'visualiserSettings',
        text = self:string("VISU_CHANGE_ON_NP_VIEW"),
        style = 'item_choice',
        weight = 42,
        check =  Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.visuChangeOnNpViewChange = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.visuChangeOnNpViewChange)
    })

    jiveMain:addItem({
        id = "caps_on",
        node = "visualiserSpectrumSettings",
        text = self:string('SPECTRUM_CAPS'),
        style = 'item_choice',
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.spectrum.capsOn = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.spectrum.capsOn)
    })

    jiveMain:addItem({
        id = "turbine",
        node = "visualiserSpectrumSettings",
        text = self:string('SPECTRUM_TURBINE'),
        style = 'item_choice',
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.spectrum.turbine = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.spectrum.turbine)
    })

    jiveMain:addItem({
        id = "baselineOn",
        node = "visualiserSpectrumSettings",
        text = self:string('SPECTRUM_BASELINEON'),
        style = 'item_choice',
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.spectrum.baselineOn = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.spectrum.baselineOn)
    })

    jiveMain:addItem({
        id = "baselineAlways",
        node = "visualiserSpectrumSettings",
        text = self:string('SPECTRUM_BASELINEALWAYS'),
        style = 'item_choice',
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.spectrum.baselineAlways = checked
            self:storeSettings()
            local np = appletManager:getAppletInstance("NowPlaying")
            if np ~= nil then
                np:invalidateWindow(nil)
            end
        end,
        settings.spectrum.baselineAlways)
    })

end

function imagesMenu(self, menuItem)
    local window = Window("text_list", self:string('RESIZE_IMAGES') )
    local menu = SimpleMenu("menu")

    menu:addItem({ text = "Resize Selected Visualiser Images",
        callback = function(event, menuItem)
            self:resizeImages(true, true, false)
        end,
        weight=10
    })

    menu:addItem({ text = "Resize Selected Spectrum Images",
        callback = function(event, menuItem)
            self:resizeImages(true, false, false)
        end,
        weight=20
    })

    menu:addItem({ text = "Resize Selected VU Meter Images",
        callback = function(event, menuItem)
            self:resizeImages(false, true, false)
        end,
        weight=30
    })

    menu:addItem({ text = "Resize ALL Spectrum Images",
        callback = function(event, menuItem)
            self:resizeImages(true, false, true)
        end,
        weight=40
    })

    menu:addItem({ text = "Resize ALL VU Meter Images",
        callback = function(event, menuItem)
            self:resizeImages(false, true, true)
        end,
        weight=50
    })

    menu:addItem({ text = "Resize ALL Visualiser Images",
        callback = function(event, menuItem)
            self:resizeImages(true, true, true)
        end,
        weight=60
    })

    menu:addItem({ text = "Delete Resized Images",
        callback = function(event, menuItem)
            visImage:cacheDelete()
        end,
        weight=70
    })

    window:addWidget(menu)
    window:show()
end

function selectSpectrumChannelFlip(self)
    local window = Window("text_list", self:string('SPECTRUM_CHANNEL_FLIP'))
    local menu = SimpleMenu("menu")
    local group = RadioGroup()
    local settings = self:getSettings()

    local channelFlips  = {
        {name="LHHL", displayName=self:string("LHHL")},
        {name="HLHL", displayName=self:string("HLHL")},
        {name="HLLH", displayName=self:string("HLLH")},
        {name="LHLH", displayName=self:string("LHLH")},
    }

    local current = settings.spectrum.channelFlip
    for i, v in ipairs(channelFlips) do
        menu:addItem( {
            text = v.displayName,
            style = 'item_choice',
            check = RadioButton("radio", group,
                function()
                    local rb_settings = self:getSettings()
                    rb_settings.spectrum.channelFlip=v.name
                    self:storeSettings()
                end,
            v.name == current),
        } )
    end

    window:addWidget(menu)
    window:show()
end

function selectSpectrumBarsFormat(self)
    local window = Window("text_list", self:string('SPECTRUM_BARS_FORMAT') )
    local menu = SimpleMenu("menu")
    local group = RadioGroup()
    local settings = self:getSettings()

    local current = settings.spectrum.barsFormat

    -- sort the bars format for display based on the number of bars that would be 
    -- rendered
    local sorted_bf = {}
    for k, v in pairs(settings.spectrum.barFormats) do
        local binWidth = (v.barsInBin * v.barWidth) + v.binSpace + ((v.barsInBin-1) * v.barSpace)
        table.insert(sorted_bf, {name=k, binWidth=binWidth})
    end
    table.sort(sorted_bf, function(left, right) return left.binWidth > right.binWidth end)

    for i, v in ipairs(sorted_bf) do
        menu:addItem( {
            text = v.name,
            style = 'item_choice',
            check = RadioButton("radio", group,
                function()
                    local rb_settings = self:getSettings()
                    rb_settings.spectrum.barsFormat=v.name
                    self:storeSettings()
                    local np = appletManager:getAppletInstance("NowPlaying")
                    if np ~= nil then
                        np:invalidateWindow(nil)
                    end
                end,
            v.name == current),
        })
    end

    window:addWidget(menu)
    window:show()
end

function selectVuMeters(self)
    local window = Window("text_list", self:string('SELECT_VUMETER') )
    local menu = SimpleMenu("menu")
    local settings = self:getSettings()

    -- use the vu meter list from the visImage module,
    -- it is sorted and has displayName values
    -- settings merely contains the list of
    -- VI meters and enable/disabled status
    local i, v
    for i, v in ipairs(visImage:getVuMeterList()) do
        local nm = v.name
        local enabled = v.enabled
        local displayName = v.displayName
--    local settings = self:getSettings()
--    local nm, enabled
--    for nm, enabled in pairs(settings.vuMeterSelection) do
--        local displayName = nm
        menu:addItem( {
            text = displayName,
            style = 'item_choice',
            check = Checkbox("checkbox", 
                function(object, isSelected)
                    local cb_settings = self:getSettings()
                    selected = isSelected
                    if isSelected then
                        self:resizeVUMeter(nm)
                        visImage:selectVuImage(nm, true, false)
                    else
                        if visImage:selectVuImage(nm, false, false) <= 0 then
                            visImage:selectVuImage(nm, true, false)
                            selected = true
                        else
                            local np = appletManager:getAppletInstance("NowPlaying")
                            if np ~= nil then
                                np:invalidateWindow(nil)
                            end
                        end
                    end
                    cb_settings.vuMeterSelection[nm] = selected
                    self:storeSettings()
                end,
            enabled),
        } )
    end

    window:addWidget(menu)
    window:show()
end

function selectSpectrumMeters(self)
    local window = Window("text_list", self:string('SELECT_SPECTRUM') )
    local menu = SimpleMenu("menu")

    -- use the spectrum meter list from the visImage module,
    -- it is sorted, settings merely contains the list of
    -- spectrum meters and enable/disabled status
    local i, v
    for i, v in ipairs(visImage.getSpectrumMeterList()) do
        local enabled = v.enabled
        local nm = v.name
--    local settings = self:getSettings()
--    local nm, enabled
--    for nm, enabled in pairs(settings.spectrumMeterSelection) do
        menu:addItem( {
            text = nm,
            style = 'item_choice',
            check = Checkbox("checkbox", 
                function(object, isSelected)
                    local cb_settings = self:getSettings()
                    selected = isSelected
                    if isSelected then
                        self:resizeSpectrumMeter(nm)
                        visImage:selectSpectrum(nm, true, false)
                    else
                        if visImage:selectSpectrum(nm, false, false) <= 0 then
                            visImage:selectSpectrum(nm, true, false)
                            selected = true
                        else
                            local np = appletManager:getAppletInstance("NowPlaying")
                            if np ~= nil then
                                np:invalidateWindow(nil)
                            end
                         end
                    end
                    cb_settings.spectrumMeterSelection[nm] = selected
                    self:storeSettings()
                end,
            enabled),
        } )
    end

    window:addWidget(menu)
    window:show()
end


function resizeImages(self, bSpectrum, bVuMeters, all)
        local popup = Popup("toast_popup_text")

        popup:setAllowScreensaver(false)
        popup:setAutoHide(false)

        -- don't allow any keypress/touch command so user cannot interrupt the resizing command
        -- popup will hide when resizing is done
        -- popup:ignoreAllInputExcept({""})

        local text = Label("text", "Resizing...")

        popup:addWidget(text)

        local tmp = {}
        local spectrum_names = {}
        tmp = visImage:getSpectrumMeterList()
        if bSpectrum then
            for k, v in pairs(tmp) do
                if (all or v.enabled) and (v.spType == visImage.SPT_BACKLIT or v.spType == SPT_IMAGE) then
                    table.insert(spectrum_names, v.name)
                else
                    log:info("skipping ",v.name, " ", v.spType, " ", (all or v.enabled), " ", all, " ", v.enabled)
                end
            end
        end

        tmp = visImage:getVuMeterList()
        local vumeter_names = {}
        if bVuMeters then
            for k, v in pairs(tmp) do
                if (all or v.enabled) and v.vutype == "frame" then
                    table.insert(vumeter_names, v.name)
                else
                    log:info("skipping ",v.name, " ", v.vutype, " ", (all or v.enabled), " ", all, " ", v.enabled)
                end
            end
        end

        local state = "resize_sp"
        local i_vu = 1
        local i_sp = 1
        local spectrum_meter_name = spectrum_names[i_sp]
        local vu_meter_name =  vumeter_names[i_vu]
        popup:addTimer(50, function()
                if state == "resize_sp" then
                    if i_sp <= #spectrum_names then
                        spectrum_meter_name = spectrum_names[i_sp]
                        -- this odd-ball pre-increment because we do not want to keep on repeating
                        -- if the resize op failed
                        i_sp = i_sp + 1
                        text:setValue("Resizing spectrum meter " .. spectrum_meter_name)
                        state = "resize_sp_exec"
                    else
                        state = "resize_vu"
                    end
                elseif state == "resize_sp_exec" then
                    log:info("resize ", spectrum_meter_name)
                    visImage:resizeSpectrumMeter(spectrum_meter_name)
                    log:info("done ", spectrum_meter_name)
                    state = "resize_sp"
                elseif state == "resize_vu" then
                    if i_vu <= #vumeter_names then
                        vu_meter_name =  vumeter_names[i_vu]
                        -- this odd-ball pre-increment because we do not want to keep on repeating
                        -- if the resize op failed
                        i_vu = i_vu + 1
                        text:setValue("Resizing VU meter " .. vu_meter_name)
                        state = "resize_vu_exec"
                    else
                        state = "resized"
                    end
                elseif state == "resize_vu_exec" then
                    log:info("resize ", vu_meter_name)
                    visImage:resizeVuMeter(vu_meter_name)
                    log:info("done ", vu_meter_name)
                    state = "resize_vu"
                elseif state == "resized" then
                    text:setValue("Resize of visualisation complete.")
                    state = "done"
                elseif state == "done" then
                    visImage:initialiseCache()
                    state = "hide"
                elseif state == "hide" then
                    popup:hide(Window.transitionFadeOut)
                end
            end)

        popup:show()
end

function resizeSpectrumMeter(self, spectrum_meter_name)
    if not visImage:resizeRequiredSpectrumMeter(spectrum_meter_name) then
        return
    end

    local popup = Popup("toast_popup_text")

    popup:setAllowScreensaver(false)
    popup:setAutoHide(false)

    -- don't allow any keypress/touch command so user cannot interrupt the resizing command
    -- popup will hide when resizing is done
    popup:ignoreAllInputExcept({""})

    local text = Label("text", "Resizing spectrum meter " .. spectrum_meter_name)

    popup:addWidget(text)

    local state = 1
    popup:addTimer(100, function()
        if state == 1 then
            if spectrum_meter_name ~= nil then
                log:info("resize ", spectrum_meter_name, " ", i_sp)
                visImage:resizeSpectrumMeter(spectrum_meter_name)
                log:info("done ", spectrum_meter_name)
            end
            state = state + 1
        elseif state == 2 then
            text:setValue("Resized spectrum meter " .. spectrum_meter_name)
            state = state +1
        else
            popup:hide(Window.transitionFadeOut)
        end
    end)

    popup:show()
end

function resizeVUMeter(self, vu_meter_name)
    if not visImage:resizeRequiredVuMeter(vu_meter_name) then
        return
    end

    local popup = Popup("toast_popup_text")

    popup:setAllowScreensaver(false)
    popup:setAutoHide(false)

    -- don't allow any keypress/touch command so user cannot interrupt the resizing command
    -- popup will hide when resizing is done
    popup:ignoreAllInputExcept({""})

    local text = Label("text", "Resizing vu meter " .. vu_meter_name)

    popup:addWidget(text)

    local state = 1
    popup:addTimer(100, function()
        if state == 1 then
            if vu_meter_name ~= nil then
                log:info("resize ", vu_meter_name, " ", i_vu)
                visImage:resizeVuMeter(vu_meter_name)
                log:info("done ", vu_meter_name)
            end
            state = state + 1
        elseif state == 2 then
            text:setValue("Resized vu meter " .. vu_meter_name)
            state = state + 1
        else
            popup:hide(Window.transitionFadeOut)
        end
    end)

    popup:show()
end
