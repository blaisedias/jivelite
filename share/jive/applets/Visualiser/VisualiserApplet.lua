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
local log			    = require("jive.utils.log").logger("jivelite.vis")

local debug             = require("jive.utils.debug")

local Applet            = require("jive.Applet")

local appletManager     = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


function menu(self, menuItem)
    local window = Window("text_list", "Visualiser")
    local menu = SimpleMenu("menu")

--    menu:addItem({ text = self:string("MENU_SAVE_SETTINGS"),
    menu:addItem({ text = "Reset Image Caches",
            callback = function(event, menuItem)
                visImage:cacheClear()
            end })


    menu:addItem({ text = "Resize Visualiser Images",
            callback = function(event, menuItem)
                self:resizeImages(menuItem, true, true)
            end })

    menu:addItem({ text = "Resize Spectrum Images",
            callback = function(event, menuItem)
                self:resizeImages(menuItem, true, false)
            end })

    menu:addItem({ text = "Resize VU Meter Images",
            callback = function(event, menuItem)
                self:resizeImages(menuItem, false, true)
            end })

    window:addWidget(menu)

    self:tieAndShowWindow(window)
    return window
end

function resizeImages(self, menuItem, bSpectrum, bVuMeters)

        local popup = Popup("toast_popup_text")

        popup:setAllowScreensaver(false)
        popup:setAutoHide(false)

        -- don't allow any keypress/touch command so user cannot interrupt the resizing command
        -- popup will hide when resizing is done
        popup:ignoreAllInputExcept({""})

--        local text = Label("text", tostring(self:string("LABEL_SAVING_SETTINGS")))
        local text = Label("text", "Resizing...")

        popup:addWidget(text)

        local tmp = {}
        local spectrum_names = {}
        tmp = visImage:getSpectrumList()
        if bSpectrum then
            for k, v in pairs(tmp) do
                if v.enabled and (v.spType == visImage.SPT_BACKLIT or v.spType == SPT_IMAGE) then
                    table.insert(spectrum_names, v.name)
                end
            end
        end

        tmp = visImage:getVUImageList()
        local vumeter_names = {}
        if bVuMeters then
            for k, v in pairs(tmp) do
                if v.enabled then
                    table.insert(vumeter_names, v.name)
                end
            end
        end

        local state = "resize sp"
        local i_vu = 1
        local i_sp = 1
        popup:addTimer(500, function()
                if state == "resize sp" then
                    if i_sp <= #spectrum_names then
                        local spectrum_meter_name = spectrum_names[i_sp]
                        log:info("resize ", spectrum_meter_name, " ", i_sp)
                        -- this odd-ball pre-increment because we do not want to keep on repeating
                        -- if the resize op failed
                        i_sp = i_sp + 1
                        text:setValue("Resizing spectrum meter " .. spectrum_meter_name)
                        visImage:resizeSpectrums(spectrum_meter_name)
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
                        visImage:resizeVuMeters(vu_meter_name)
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

        self:tieAndShowWindow(popup, Window.transitionFadeIn)
        return popup
end


