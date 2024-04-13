local tostring          = tostring
local tonumber          = tonumber
local pairs             = pairs

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
local Choice            = require("jive.ui.Choice")
local Textinput         = require("jive.ui.Textinput")
local Keyboard          = require("jive.ui.Keyboard")
local visImage          = require("jive.visImage")
local log			    = require("jive.utils.log").logger("applet.Visualiser")

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
        text = "Cache Visualiser Images in RAM",
        style = 'item_choice',
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
        text = "Randomise Visualiser Sequence",
        style = 'item_choice',
        check =  Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.randomSequence = checked
    		self:storeSettings()
        	end,
            settings.randomSequence)
    })
end

function imagesMenu(self, menuItem)
    local window = Window("text_list", "Images")
    local menu = SimpleMenu("menu")

    menu:addItem({ text = "Reset Image Caches",
        callback = function(event, menuItem)
            visImage:cacheClear()
        end
    })

    menu:addItem({ text = "Resize Selected Visualiser Images",
        callback = function(event, menuItem)
            self:resizeImages(self, true, true, false)
        end
    })

    menu:addItem({ text = "Resize Selected Spectrum Images",
        callback = function(event, menuItem)
            self:resizeImages(self, true, false, false)
        end
    })

    menu:addItem({ text = "Resize Selected VU Meter Images",
        callback = function(event, menuItem)
            self:resizeImages(self, false, true, false)
        end
    })

    menu:addItem({ text = "Resize ALL Visualiser Images",
        callback = function(event, menuItem)
            self:resizeImages(self, true, true, true)
        end
    })

    menu:addItem({ text = "Resize ALL Spectrum Images",
        callback = function(event, menuItem)
            self:resizeImages(self, true, false, true)
        end
    })

    menu:addItem({ text = "Resize ALL VU Meter Images",
        callback = function(event, menuItem)
            self:resizeImages(self, false, true, true)
        end
    })
    window:addWidget(menu)
    window:show()
end


function resizeImages(tbl, self, bSpectrum, bVuMeters, all)

        local popup = Popup("toast_popup_text")

        popup:setAllowScreensaver(false)
        popup:setAutoHide(false)

        -- don't allow any keypress/touch command so user cannot interrupt the resizing command
        -- popup will hide when resizing is done
        popup:ignoreAllInputExcept({""})

        local text = Label("text", "Resizing...")

        popup:addWidget(text)

        local tmp = {}
        local spectrum_names = {}
        tmp = visImage:getSpectrumList()
        if bSpectrum then
            for k, v in pairs(tmp) do
                if (all or v.enabled) and (v.spType == visImage.SPT_BACKLIT or v.spType == SPT_IMAGE) then
                    table.insert(spectrum_names, v.name)
                else
                    log:info("skipping ",v.name, " ", v.spType, " ", (all or v.enabled), " ", all, " ", v.enabled)  
                end
            end
        end

        tmp = visImage:getVUImageList()
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

        local state = "resize sp"
        local i_vu = 1
        local i_sp = 1
        popup:addTimer(50, function()
                if state == "resize sp" then
                    if i_sp <= #spectrum_names then
                        local spectrum_meter_name = spectrum_names[i_sp]
                        log:info("resize ", spectrum_meter_name, " ", i_sp)
                        -- this odd-ball pre-increment because we do not want to keep on repeating
                        -- if the resize op failed
                        i_sp = i_sp + 1
                        text:setValue("Resizing spectrum meter " .. spectrum_meter_name)
                        visImage:resizeSpectrumMeter(spectrum_meter_name)
                        text:setValue("Resized spectrum meter " .. spectrum_meter_name)
                        log:info("done ", spectrum_meter_name)
                    else
                        state = "resize vu"
                    end
                elseif state == "resize vu" then
                    if i_vu <= #vumeter_names then
                        local vu_meter_name =  vumeter_names[i_vu]
                        log:info("resize ", vu_meter_name, " ", i_vu)
                        -- this odd-ball pre-increment because we do not want to keep on repeating
                        -- if the resize op failed
                        i_vu = i_vu + 1
                        text:setValue("Resizing VU meter " .. vu_meter_name)
                        visImage:resizeVuMeter(vu_meter_name)
                        text:setValue("Resized VU meter " .. vu_meter_name)
                        log:info("done ", vu_meter_name)
                    else
                        state = "resized"
                    end
                elseif state == "resized" then
                    text:setValue("Resize of visualisation complete.")
                    state = "done"
                elseif state == "done" then
                    state = "hide"
                elseif state == "hide" then
                    popup:hide(Window.transitionFadeOut)
                end
            end)

        popup:show()
end

function resizeSpectrumMeter(tbl, self, spectrum_meter_name)
    local resizable = false
    local tmp = {}
    local spectrum_names = {}
    tmp = visImage:getSpectrumList()
    for k, v in pairs(tmp) do
        if v.name == spectrum_meter_name and (v.spType == visImage.SPT_BACKLIT or v.spType == SPT_IMAGE) then
            resizable = true
        end
    end

   if not resizable then
       return
   end

    local popup = Popup("toast_popup_text")

    popup:setAllowScreensaver(false)
    popup:setAutoHide(false)

    -- don't allow any keypress/touch command so user cannot interrupt the resizing command
    -- popup will hide when resizing is done
    popup:ignoreAllInputExcept({""})


    local msgResizing = "Resizing"
    local msgResized = "Resized"
    msgResizing = msgResizing .. " Spectrum Meter:" .. spectrum_meter_name
    msgResized = msgResized .. " Spectrum Meter:" .. spectrum_meter_name
    local text = Label("text", msgResizing)

    popup:addWidget(text)

    local state = "resize sp"
    popup:addTimer(50, function()
        if state == "resize sp" then
            if spectrum_meter_name ~= nil then
                log:info("resize ", spectrum_meter_name, " ", i_sp)
                visImage:resizeSpectrumMeter(spectrum_meter_name)
                log:info("done ", spectrum_meter_name)
            end
            state = "resize vu"
        elseif state == "resize vu" then
            state = "resized"
        elseif state == "resized" then
            text:setValue(msgResized)
            state = "done"
        elseif state == "done" then
            state = "hide"
        elseif state == "hide" then
            popup:hide(Window.transitionFadeOut)
        end
    end)

    popup:show()
end

function resizeVUMeter(tbl, self, vu_meter_name)
    local resizable = false
    local tmp = visImage:getVUImageList()
    for k, v in pairs(tmp) do
        if v.name == vu_meter_name then
            if v.vutype == "frame" then
                resizable = true
            end
        end
    end

    if not resizable then
        return
    end

    local popup = Popup("toast_popup_text")

    popup:setAllowScreensaver(false)
    popup:setAutoHide(false)

    -- don't allow any keypress/touch command so user cannot interrupt the resizing command
    -- popup will hide when resizing is done
    popup:ignoreAllInputExcept({""})


    local msgResizing = "Resizing"
    local msgResized = "Resized"
    msgResizing = msgResizing .. " VU Meter:" .. vu_meter_name
    msgResized = msgResized .. " VU Meter:" .. vu_meter_name
    local text = Label("text", msgResizing)

    popup:addWidget(text)

    local state = "resize sp"
    popup:addTimer(50, function()
        if state == "resize sp" then
            state = "resize vu"
        elseif state == "resize vu" then
            if vu_meter_name ~= nil then
                log:info("resize ", vu_meter_name, " ", i_vu)
                visImage:resizeVuMeter(vu_meter_name)
                log:info("done ", vu_meter_name)
            end
            state = "resized"
        elseif state == "resized" then
            text:setValue(msgResized)
            state = "done"
        elseif state == "done" then
            state = "hide"
        elseif state == "hide" then
            popup:hide(Window.transitionFadeOut)
        end
    end)

    popup:show()
end
