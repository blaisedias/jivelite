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
        text = self:string("VISUALISER_CACHE_IMAGE_RAM"),
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
        text = self:string("VISUALISER_RANDOMISE_SEQUENCE"),
        style = 'item_choice',
        check =  Checkbox("checkbox", function(applet, checked)
            local cb_settings = self:getSettings()
            cb_settings.randomSequence = checked
    		self:storeSettings()
        	end,
            settings.randomSequence)
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
    	end,
        settings.spectrum.baselineAlways)
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

local channelFlips  = {
	{name="Low Freq > High Freq, High Freq > Low Freq", values={0,1}},
	{name="High Freq > Low Freq, High Freq > Low Freq", values={1,1}},
	{name="High Freq > Low Freq, Low Freq > High Freq", values={1,0}},
	{name="Low Freq > High Freq, Low Freq > High Freq", values={0,0}},
}

function selectSpectrumChannelFlip(self)
    local window = Window("text_list", "SPECTRUM_CHANNEL_FLIP")
    local menu = SimpleMenu("menu")
	local group = RadioGroup()
    local settings = self:getSettings()

    local current = settings.spectrum.channelFlip
    log:info("###### 1")
	for i, v in ipairs(channelFlips) do
        log:info("###### 2 ", i)
		menu:addItem( {
			text = v.name,
			style = 'item_choice',
			check = RadioButton("radio", group,
				function()
                    local rb_settings = self:getSettings()
					rb_settings.spectrum.channelFlip=v
					self:storeSettings()
				end,
			v.name == current.name),
		} )
	end

    window:addWidget(menu)
    window:show()
end

local barsFormats  = {
	{name="2-1-3-6", values={barsInBin=2, barWidth=1, barSpace=3, binSpace=6}},
	{name="2-2-3-4", values={barsInBin=2, barWidth=2, barSpace=3, binSpace=4}},
	{name="2-3-3-2", values={barsInBin=2, barWidth=3, barSpace=3, binSpace=2}},
	{name="2-4-1-4", values={barsInBin=2, barWidth=4, barSpace=1, binSpace=4}},
	{name="1-10-0-10", values={barsInBin=1, barWidth=10, barSpace=0, binSpace=10}},
	{name="2-03-2-10", values={barsInBin=2, barWidth=3, barSpace=2, binSpace=10}},
	{name="2-04-3-06", values={barsInBin=2, barWidth=4, barSpace=3, binSpace=6}},
	{name="3-03-2-05", values={barsInBin=3, barWidth=3, barSpace=2, binSpace=5}},
	{name="4-02-2-04", values={barsInBin=4, barWidth=2, barSpace=2, binSpace=4}},
	{name="1-15-0-5", values={barsInBin=1, barWidth=15, barSpace=0, binSpace=5}},
	{name="1-18-0-2", values={barsInBin=1, barWidth=18, barSpace=0, binSpace=2}},
	{name="2-07-2-5", values={barsInBin=2, barWidth=7, barSpace=2, binSpace=5}},
	{name="2-05-4-5", values={barsInBin=2, barWidth=5, barSpace=4, binSpace=5}},
	{name="3-03-2-5", values={barsInBin=3, barWidth=3, barSpace=2, binSpace=5}},
	{name="1-10-0-5", values={barsInBin=1, barWidth=10, barSpace=0, binSpace=5}},
	{name="1-13-0-2", values={barsInBin=1, barWidth=13, barSpace=0, binSpace=2}},
	{name="1-4-0-6", values={barsInBin=1, barWidth=4, barSpace=0, binSpace=6}},
	{name="1-6-0-4", values={barsInBin=1, barWidth=6, barSpace=0, binSpace=4}},
	{name="1-8-0-2", values={barsInBin=1, barWidth=8, barSpace=0, binSpace=2}},
	{name="1-5-0-5", values={barsInBin=1, barWidth=5, barSpace=0, binSpace=5}},
	{name="1-5-0-3", values={barsInBin=1, barWidth=5, barSpace=0, binSpace=3}},
	{name="1-4-0-4", values={barsInBin=1, barWidth=4, barSpace=0, binSpace=4}},
	{name="1-4-0-3", values={barsInBin=1, barWidth=4, barSpace=0, binSpace=3}},
	{name="1-5-0-2", values={barsInBin=1, barWidth=5, barSpace=0, binSpace=2}},
	{name="2-2-1-2", values={barsInBin=2, barWidth=2, barSpace=1, binSpace=2}},
	{name="1-4-0-2", values={barsInBin=1, barWidth=4, barSpace=0, binSpace=2}},
	{name="1-3-0-3", values={barsInBin=1, barWidth=3, barSpace=0, binSpace=3}},
	{name="1-3-0-2", values={barsInBin=1, barWidth=3, barSpace=0, binSpace=2}},
	{name="2-1-1-2", values={barsInBin=2, barWidth=1, barSpace=1, binSpace=2}},
	{name="1-2-0-2", values={barsInBin=1, barWidth=2, barSpace=0, binSpace=2}},
	{name="1-3-0-1", values={barsInBin=1, barWidth=3, barSpace=0, binSpace=1}},
	{name="1-2-0-1", values={barsInBin=1, barWidth=2, barSpace=0, binSpace=1}},
	{name="1-1-1-1", values={barsInBin=1, barWidth=1, barSpace=0, binSpace=1}},
}


function selectSpectrumBarsFormat(self)
	local window = Window("text_list", self:string('SPECTRUM_BARS_FORMAT') )
	local menu = SimpleMenu("menu")
	local group = RadioGroup()
    local settings = self:getSettings()

	local current = settings.spectrum.barsFormat

	for i, v in ipairs(barsFormats) do
		menu:addItem( {
			text = v.name,
			style = 'item_choice',
			check = RadioButton("radio", group,
				function()
                    local rb_settings = self:getSettings()
					rb_settings.spectrum.barsFormat=v
					self:storeSettings()
				end,
			v.name == current.name),
		})
	end

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
