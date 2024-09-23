--local tostring          = tostring
local tonumber          = tonumber
local pairs             = pairs
local ipairs            = ipairs

local table             = require("table")
local string            = require("string")
--local math              = require("math")
--local os                = require("os")
--local io                = require("io")
local oo                = require("loop.simple")
--local Event             = require("jive.ui.Event")
local Icon              = require("jive.ui.Icon")
local Label             = require("jive.ui.Label")
local Popup             = require("jive.ui.Popup")
local SimpleMenu        = require("jive.ui.SimpleMenu")
local Window            = require("jive.ui.Window")
--local Slider            = require("jive.ui.Slider")
--local Textarea          = require("jive.ui.Textarea")
local Group             = require("jive.ui.Group")
local Framework         = require("jive.ui.Framework")
local Checkbox          = require("jive.ui.Checkbox")
local RadioButton       = require("jive.ui.RadioButton")
local RadioGroup        = require("jive.ui.RadioGroup")
--local Choice            = require("jive.ui.Choice")
local Textinput         = require("jive.ui.Textinput")
local Keyboard          = require("jive.ui.Keyboard")
local visImage          = require("jive.visImage")
local log               = require("jive.utils.log").logger("applet.Visualiser")

--local debug             = require("jive.utils.debug")

local Applet            = require("jive.Applet")

local appletManager     = appletManager
local jiveMain      = jiveMain

module(..., Framework.constants)
oo.class(_M, Applet)

function inputVisualiserChangeOnTimer(self)
    local window = Window("text_list", self:string("CHANGE_VISUALISER_ON_TIMER"))
    local settings = self:getSettings()

    local currentValue = settings.visuChangeOnTimer
    if currentValue == nil then
        currentValue = ''
    else
        currentValue = ''.. currentValue
    end

    local v = Textinput.integerValue(currentValue)
    local input = Textinput("textinput", v,
            function(_, value)
                settings.visuChangeOnTimer = tonumber(value.s)
                self:storeSettings()
                window:hide()
            end
    )

    local keyboard = Keyboard("keyboard", "integer", input)
    local backspace = Keyboard.backspace()
        local group = Group('keyboard_textinput', { textinput = input, backspace = backspace } )

    window:addWidget(group)
    window:addWidget(keyboard)
    window:focusWidget(group)

    self:tieAndShowWindow(window)
    return window
end


local function refreshNowPlaying()
    local np = appletManager:getAppletInstance("NowPlaying")
    if np ~= nil then
        np:invalidateWindow(nil)
    end
end


function init(self)
    local settings = self:getSettings()

    jiveMain:addItem({
        id = "vic",
        node = 'visualiserSettings',
        text = self:string("VISUALISER_CACHE_IMAGE_RAM"),
        style = 'item_choice',
        weight = 50,
--        check = Checkbox("checkbox", function(applet, checked)
        check = Checkbox("checkbox", function(_, checked)
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
--        check =  Checkbox("checkbox", function(applet, checked)
        check =  Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.randomSequence = checked
            self:storeSettings()
            refreshNowPlaying()
        end,
        settings.randomSequence)
    })

    jiveMain:addItem({
        id = "visuChangeOnTrackChange",
        node = 'visualiserSettings',
        text = self:string("VISU_CHANGE_ON_TRACK_CHANGE"),
        style = 'item_choice',
        weight = 41,
--        check =  Checkbox("checkbox", function(applet, checked)
        check =  Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.visuChangeOnTrackChange = checked
            self:storeSettings()
            refreshNowPlaying()
        end,
        settings.visuChangeOnTrackChange)
    })

    jiveMain:addItem({
        id = "visuChangeOnNpViewChange",
        node = 'visualiserSettings',
        text = self:string("VISU_CHANGE_ON_NP_VIEW"),
        style = 'item_choice',
        weight = 42,
--        check =  Checkbox("checkbox", function(applet, checked)
        check =  Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.visuChangeOnNpViewChange = checked
            self:storeSettings()
            refreshNowPlaying()
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
            refreshNowPlaying()
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
            refreshNowPlaying()
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
            refreshNowPlaying()
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
            refreshNowPlaying()
        end,
        settings.spectrum.baselineAlways)
    })

end

local function inputWorkSpace(self)
    local window = Window("text_list", self:string("WORKSPACE_PATH"))
    local settings = self:getSettings()

    local currentValue = settings.workSpace
    if currentValue == nil then
        currentValue = ''
    else
        currentValue = ''.. currentValue
    end

    if string.len(currentValue) == 0 and settings.persisentStorageRoot ~= nil then
        -- unset - pre-fill with recommended value if a persistent storage path
        -- is defined
        currentValue = settings.persisentStorageRoot .. '/jivelite-workspace'
    end

    local v = Textinput.textValue(currentValue)
    local input = Textinput("textinput", v,
            function(_, value)
                -- reject the path if it is identical to settings.persistenStorageRoot
                -- as this might be an indication that the user has not set it.
                if value.s == settings.persisentStorageRoot ~= nil then
                    settings.workSpace = value.s
                    self:storeSettings()
                end
                window:hide()
            end
    )

    local keyboard = Keyboard("keyboard", "qwerty", input)
    local backspace = Keyboard.backspace()
        local group = Group('keyboard_textinput', { textinput = input, backspace = backspace } )

    window:addWidget(group)
    window:addWidget(keyboard)
    window:focusWidget(group)

    self:tieAndShowWindow(window)
    return window
end


--function imagesMenu(self, menuItem)
function imagesMenu(self, _)
    local window = Window("text_list", self:string('RESIZE_IMAGES') )
    local menu = SimpleMenu("menu")
    local settings = self:getSettings()

    menu:addItem({ text = "Resize Selected Visualiser Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(true, true, false)
        end,
        weight=10
    })

    menu:addItem({ text = "Resize Selected Spectrum Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(true, false, false)
        end,
        weight=20
    })

    menu:addItem({ text = "Resize Selected VU Meter Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(false, true, false)
        end,
        weight=30
    })

    menu:addItem({ text = "Resize ALL Spectrum Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(true, false, true)
        end,
        weight=40
    })

    menu:addItem({ text = "Resize ALL VU Meter Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(false, true, true)
        end,
        weight=50
    })

    menu:addItem({ text = "Resize ALL Visualiser Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            self:resizeImages(true, true, true)
        end,
        weight=60
    })

    menu:addItem({ text = "Delete Resized Images",
--        callback = function(event, menuItem)
        callback = function(_, _)
            visImage:deleteResizedImages()
            refreshNowPlaying()
        end,
        weight=70
    })

    menu:addItem({
        id = "saveresized",
        text = self:string("SAVE_RESIZED"),
        style = 'item_choice',
        weight = 80,
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.saveResizedImages = checked
            self:storeSettings()
            end,
            settings.saveResizedImages)
    })

    menu:addItem({
        id = "saveaspng",
        text = self:string("SAVE_AS_PNG"),
        style = 'item_choice',
        weight = 90,
        check = Checkbox("checkbox", function(_, checked)
            local cb_settings = self:getSettings()
            cb_settings.saveAsPng = checked
            self:storeSettings()
            end,
            settings.saveAsPng)
    })

    window:addWidget(menu)
    window:show()
end

--function workspaceMenu(self, menuItem)
function workspaceMenu(self, _)
    local window = Window("text_list", self:string('WORKSPACE') )
    local menu = SimpleMenu("menu")
    local settings = self:getSettings()

    -- workspace UI is complicated
    -- present information to the user and the ability to change it
    -- show default, and current values
    menu:addItem({ text =  'Default workspace path: ' .. visImage:getDefaultWorkspacePath(),
            style = 'item_no_arrow',
            weight=100
    })
    menu:addItem({ text =  'Current workspace path: ' .. visImage:getWorkspacePath(),
            style = 'item_no_arrow',
            weight=110
    })
    -- if persistent storage path is defined then offer recommended values
    if settings.persisentStorageRoot ~= nil then
        menu:addItem({ text = 'Recommended workspace path: ' .. settings.persisentStorageRoot .. '/jivelite-workspace',
            style = 'item_no_arrow',
            weight=120
        })
    end
    menu:addItem({ text = self:string("WORKSPACE_PATH"),
--        callback = function(event, menuItem)
        callback = function(_, _)
            inputWorkSpace(self)
        end,
        weight=130
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
    for _, v in ipairs(channelFlips) do
        menu:addItem( {
            text = v.displayName,
            style = 'item_choice',
            check = RadioButton("radio", group,
                function()
                    local rb_settings = self:getSettings()
                    rb_settings.spectrum.channelFlip=v.name
                    self:storeSettings()
                    refreshNowPlaying()
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

    for _, v in ipairs(sorted_bf) do
        menu:addItem( {
            text = v.name,
            style = 'item_choice',
            check = RadioButton("radio", group,
                function()
                    local rb_settings = self:getSettings()
                    rb_settings.spectrum.barsFormat=v.name
                    self:storeSettings()
                    refreshNowPlaying()
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
--  uncomment to trigger resize on exit from the menu
--    menu.closeAction = "go_resize_visu"

--    local settings = self:getSettings()

    -- use the vu meter list from the visImage module,
    -- it is sorted and has displayName values
    -- settings merely contains the list of
    -- VI meters and enable/disabled status
    for _, v in ipairs(visImage:getVuMeterList()) do
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
--                function(object, isSelected)
                function(_, isSelected)
                    local cb_settings = self:getSettings()
                    local selected = isSelected
                    if isSelected then
                        visImage:selectVuImage(nm, true)
                    else
                        if visImage:selectVuImage(nm, false) <= 0 then
                            visImage:selectVuImage(nm, true)
                            selected = true
                        else
                            refreshNowPlaying()
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
--  uncomment to trigger resize on exit from the menu
--    menu.closeAction = "go_resize_visu"

    -- use the spectrum meter list from the visImage module,
    -- it is sorted, settings merely contains the list of
    -- spectrum meters and enable/disabled status
    for _, v in ipairs(visImage:getSpectrumMeterList()) do
        local enabled = v.enabled
        local nm = v.name
--    local settings = self:getSettings()
--    local nm, enabled
--    for nm, enabled in pairs(settings.spectrumMeterSelection) do
        menu:addItem( {
            text = nm,
            style = 'item_choice',
            check = Checkbox("checkbox",
--                function(object, isSelected)
                function(_, isSelected)
                    local cb_settings = self:getSettings()
                    local selected = isSelected
                    if isSelected then
                        visImage:selectSpectrum(nm, true)
                    else
                        if visImage:selectSpectrum(nm, false) <= 0 then
                            visImage:selectSpectrum(nm, true)
                            selected = true
                        else
                            refreshNowPlaying()
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


local function localResizeImages(bSpectrum, bVuMeters, all)
        local popup = Popup("toast_popup_mixed")

        popup:setAllowScreensaver(false)
        popup:setAlwaysOnTop(true)
        popup:setAutoHide(false)

        local icon = Icon("icon_connecting")
        local text = Label("text", "Resizing...")

        popup:addWidget(icon)
        popup:addWidget(text)

        local spectrumMeters = {}
        if bSpectrum then
            spectrumMeters = visImage:enumerateResizableSpectrumMeters(all)
        end

        local vuMeters = {}
        if bVuMeters then
            vuMeters = visImage:enumerateResizableVuMeters(all)
        end

        local state = "resize_sp"
        local i_vu = 1
        local i_sp = 1
        popup:addTimer(50, function()
                if state == "resize_sp" then
                    if i_sp <= #spectrumMeters then
                        local entry = spectrumMeters[i_sp]
                        text:setValue("Resizing spectrum meter " .. i_sp .. " of ".. #spectrumMeters .."\n"  .. entry.name .. "\n" .. entry.w .. "x" .. entry.h)
                        if visImage:concurrentResizeSpectrumMeter(entry.name, entry.w, entry.h) then
                            i_sp = i_sp + 1
                        end
                    else
                        state = "resize_vu"
                    end
                elseif state == "resize_vu" then
                    if i_vu <= #vuMeters then
                        local entry = vuMeters[i_vu]
                        text:setValue( "Resizing VU meter " .. i_vu .. " of " .. #vuMeters .."\n" .. entry.name .. "\n" .. entry.w .. "x" .. entry.h)
                        if visImage:concurrentResizeVuMeter(entry.name, entry.w, entry.h) then
                            i_vu = i_vu + 1
                        end
                    else
                        state = "resized"
                    end
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

function resizeImages(_, bSpectrum, bVuMeters, all)
    localResizeImages(bSpectrum, bVuMeters, all)
    refreshNowPlaying()
end

function resizeSelectedVisualisers(self)
    self:resizeImages(true, true, false)
end
