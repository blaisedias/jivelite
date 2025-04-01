--[[
 =head1 NAME

 applets.JogglerSkin.JogglerScaler

 =head1 DESCRIPTION

 Implements supoort for scaling for Joggler User Interface elements,
 including scaling the images.

 (c) Blaise Dias, 2025

 =cut
 --]]

--
local pairs = pairs
-- local tonumber = tonumber
local pcall = pcall
-- local type = type

-- lua package imports
local math  = require("math")
local lfs   = require("lfs")
local os    = require("os")
local io    = require("io")

-- jive package imports
local Surface = require("jive.ui.Surface")
local log     = require("jive.utils.log").logger("applet.JogglerSkin")
local System  = require("jive.System")
local Framework     = require("jive.ui.Framework")
local json          = require("jive.json")
local table         = require("jive.utils.table")

-- package global variables
local textScaleFactor
local imageScaleFactor
local gridTextScaleFactor
local jsonData
local resolutionKey

module(...)

local function _loadJsonData(jsPath)
    local file = io.open(jsPath, "rb")
    if file ~= nil then
        log:info("found file ", jsPath)
        local content = file:read "*a"
        file:close()
        local status, jsonContent = pcall(json.parse, content)
        if status then
            log:debug("loaded json ", jsPath)
            return jsonContent
        else
            log:error("json.parse ", jsPath, " error: ", jsonContent)
        end
    else
        log:info("loadJson: failed to open file ", jsPath)
    end
    return nil
end

local function _writeScaledData(obj, jsPath)
    local data = {}
    data[resolutionKey] = obj
    local jsonString = json.stringify(data)
    local fh = io.open(jsPath, "w")
    if fh then
        fh:write(jsonString)
        fh:close()
        log:debug("wrote scaled data json ", jsPath)
    end
end

-- reset static variables so that determination of scaling values
-- proceeds afresh
function initialise()
    textScaleFactor = nil
    imageScaleFactor = nil
    gridTextScaleFactor = nil
    jsonData = nil
    resolutionKey = nil
    local screenWidth, screenHeight = Framework:getScreenSize()
    resolutionKey = screenWidth .. 'x' .. screenHeight
    jsonData = _loadJsonData(System.getUserDir() .. '/Joggler.json')
    if jsonData and jsonData[resolutionKey] then
        local jd = jsonData[resolutionKey]['jogglerSkin']
        if jd ~= nil then
            textScaleFactor = jd.textScaleFactor
            imageScaleFactor = jd.imageScaleFactor
            -- remove fields that are derived values
            jd.imgPath = nil
            jd.scalingRequired = nil
        end
        jd = jsonData[resolutionKey]['gridSkin']
        if jd ~= nil then
            gridTextScaleFactor = jd.gridTextScaleFactor
            -- remove fields that are derived values
            jd.imgPath = nil
            jd.scalingRequired = nil
        end
    end
end

-- global function scale a text size value to match the display dimensions
function scaleTextValue(v)
    if textScaleFactor == nil then
        -- default to scaling of 1
        textScaleFactor = 1
        local screenWidth, screenHeight = Framework:getScreenSize()
        if Framework:getGlobalSetting("jogglerScaleUp") and screenHeight > 480 then
            -- landscape
            if screenWidth > screenHeight then
                textScaleFactor = screenHeight / 480
            end
            -- portrait
--            if screenWidth < screenHeight then
--                textScaleFactor = screenWidth / 800
--            end
--            for now only explicitly support portrait mode 720x1280
            if screenWidth == 720 and screenHeight == 1280 then
                textScaleFactor = 1.7
            end
        end
    end
    return math.floor(textScaleFactor * v)
end

-- global function scale a text size value to match the display dimensions for grid items
function scaleGridTextValue(v)
    if gridTextScaleFactor == nil then
        -- default to scaling of 1
        gridTextScaleFactor = 1
        if Framework:getGlobalSetting("jogglerScaleUp") then
            local screenWidth, screenHeight = Framework:getScreenSize()
            if screenHeight > 480 then
                if screenWidth > screenHeight then
                    gridTextScaleFactor = ((screenHeight * 0.0008333333333333334) + 0.6)
                else
                    -- portrait mode
                    gridTextScaleFactor = ((screenWidth * 0.0008333333333333334) + 0.6)
                end
            end
        end
    end
    return math.floor(gridTextScaleFactor * v)
end

-- global function scale an image size value to match the display dimensions
function scaleImageValue(v)
    if imageScaleFactor == nil then
        -- default to scaling of 1
        imageScaleFactor = 1
        local screenWidth, screenHeight = Framework:getScreenSize()
        if Framework:getGlobalSetting("jogglerScaleUp") then
            -- landscape
            if screenWidth > screenHeight then
                imageScaleFactor = screenHeight / 480
            end
            -- portrait
--            if screenWidth < screenHeight then
--                imageScaleFactor = screenWidth / 800
--            end
--            for now only explicitly support portrait mode 720x1280
            if screenWidth == 720 and screenHeight == 1280 then
                imageScaleFactor = screenWidth / 480
            end
        end
    end
    return math.floor(imageScaleFactor * v)
end

-- private function scales an image to match input width and height
-- if either one but not both are nil, then src dimension is used.
local function scaleImage(imgPath, w, h)
    log:debug("scaleImage imagePath:", imgPath, " w:", w, " h:", h)
    local img = Surface:altLoadImage(imgPath)
    if img == nil then
        log:warn("scaleImage: failed to load ", imgPath)
        return nil
    end
    local srcW, srcH = img:getSize()
    if w == nil then
--        w = math.floor(srcW * h/srcH)
        w = srcW
    end
    if h == nil then
--        h = math.floor(srcH * h/srcW)
        h = srcH
    end
    if srcW == w and h == srcH then
        log:debug("scaleImage no scaling", img)
        return img
    end
    local retImg = img:resize(w, h)
    log:debug("scaleImage:", srcW, "x", srcH, " to ", w, "x", h)
    img:release()
    return retImg
end


-- private function scales all images found in a path, to match input width and height
-- images discovery is not recursive.
local function scaleImagesInPath(src_path, dest_path, w, h)
    for entry in lfs.dir(src_path) do
        if entry ~= "." and entry ~= ".." then
            local mode = lfs.attributes(src_path .. "/" .. entry, "mode")
            if mode == "file" then
                mode = lfs.attributes(dest_path .. "/" .. entry, "mode")
                if mode ~= "file"  then
                    local img = scaleImage(src_path .. "/" .. entry, w, h)
                    if img ~= nil then
                        img:savePNG(dest_path .. '/' .. entry)
                        img:release()
                    else
                        log:warn("failed to scale ", src_path .. '/' .. entry)
                    end
                end
            end
        end
    end
end

-- private function scales a single image found in a path, to match input width and height
-- images discovery is not recursive.
local function scaleImageInPath(image_name, src_path, dest_path, w, h)
            local mode = lfs.attributes(src_path .. "/" .. image_name, "mode")
            if mode == "file" then
                mode = lfs.attributes(dest_path .. "/" .. image_name, "mode")
                if mode ~= "file"  then
                    local img = scaleImage(src_path .. "/" .. image_name, w, h)
                    if img ~= nil then
                        img:savePNG(dest_path .. '/' .. image_name)
                        img:release()
                    else
                        log:warn("failed to scale ", src_path .. '/' .. image_name)
                    end
                end
            end
end

-- global function scale images required for Joggler based skins
function scaleUIImages(images_path, params)
    local resizedPath = System.getUserDir() .. '/' .. params.imgPath
    os.execute("mkdir -p " .. resizedPath .. '/grid_list')
    os.execute("mkdir -p " .. resizedPath .. '/5_line_lists')
    os.execute("mkdir -p " .. resizedPath .. '/IconsResized')
    os.execute("mkdir -p " .. resizedPath .. '/Buttons')
    log:info("scaleUIImages ", images_path , " -> ", resizedPath)
    if (lfs.attributes(images_path, "mode") ~= "directory") then
        log:warn("scaleUIImages: ", images_path, " is not a directory")
        return
    end

    if params.GRID_ITEM_HEIGHT ~= nil then
        scaleImagesInPath(
            images_path .. "/grid_list",
            resizedPath .. '/grid_list',
            nil,
            params.GRID_ITEM_HEIGHT
         )
    end

    if params.FIVE_ITEM_HEIGHT ~= nil then
        scaleImagesInPath(
            images_path .. "/5_line_lists",
            resizedPath .. '/5_line_lists',
            nil,
            params.FIVE_ITEM_HEIGHT
         )
    end

    scaleImagesInPath(
        images_path .. "/IconsResized",
        resizedPath .. '/IconsResized',
        params.THUMB_SIZE,
        params.THUMB_SIZE
    )

    scaleImagesInPath(
        images_path .. "/Buttons",
        resizedPath .. '/Buttons',
        nil,
        params.TITLE_HEIGHT - 18
    )
end


local BASE_ICON_SIZE = 40
local BASE_POPUP_THUMBSIZE = 120
local jogglerImgpath = "applets/JogglerSkin/images/"

local function _getJogglerCoreParams(skinName, skinValues)
    local screenWidth, screenHeight = Framework:getScreenSize()
    if Framework:getGlobalSetting("jogglerScaleUp") then
        -- padding at the bottom is nominally 16
        local availHeight = screenHeight - skinValues.TITLE_HEIGHT - 16
        local fiveItemHeight = math.floor(availHeight/math.floor(availHeight/(skinValues.TEXTMENU_FONT_SIZE * 1.8)))
        local rows =  math.floor(availHeight/fiveItemHeight)
        if skinName == "PiGridSkin" then
            if rows % 3 ~= 0 then
                -- grid item height = 3 * fiveItemHeight,
                -- increase the number of rows to be a multiple of 3 == to a single row in the GridSkin
                -- then derive fiveItemHeight using the adjusted number of rows
                rows = math.floor((rows+2)/3)*3
                log:info("fiveItemHeight adjusted for PiGridSkin requirements ",
                            fiveItemHeight, ' -> ', math.floor(availHeight/rows)
                        )
                fiveItemHeight = math.floor(availHeight/rows)
            end
        end
        -- visually, fuzzy padding at the bottom is better, sacrifice up to X pixels,
        -- if we can increment fiveItemHeight by 1
        if availHeight%(rows * fiveItemHeight) + 7 >= rows then
            fiveItemHeight = fiveItemHeight + 1
        end
        local popupThumbSize = scaleImageValue(BASE_POPUP_THUMBSIZE)
        if screenWidth == 720 and screenHeight == 1280 then
            local thumbSize = 72
            return {
                    THUMB_SIZE=thumbSize,
--                  POPUP_THUMB_SIZE=192,
                    POPUP_THUMB_SIZE=popupThumbSize,
                    FIVE_ITEM_HEIGHT=fiveItemHeight,
                    NP_TEXT_SCALE_FACTOR = math.min(screenHeight/480, 1.4),
                    NP_SPACING_FACTOR = 1.7,
                    imgPath = jogglerImgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        end

        -- screenHeight < 480 => scale down TBD
        if screenWidth > screenHeight and screenHeight >=480 then
            local thumbSize = scaleImageValue(BASE_ICON_SIZE)
            return {
                    THUMB_SIZE=thumbSize,
                    POPUP_THUMB_SIZE=popupThumbSize,
                    FIVE_ITEM_HEIGHT=fiveItemHeight,
                    NP_TEXT_SCALE_FACTOR = scaleTextValue(1),
                    NP_SPACING_FACTOR = 1.9,
                    imgPath = jogglerImgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        end
    end
    local screenAR = screenWidth/screenHeight
    if screenHeight < 480 and screenAR < 3 then
    return {
            THUMB_SIZE=BASE_ICON_SIZE,
            POPUP_THUMB_SIZE=BASE_POPUP_THUMBSIZE,
            FIVE_ITEM_HEIGHT=45,
            NP_TEXT_SCALE_FACTOR = math.min(screenHeight/480, 0.8),
            NP_SPACING_FACTOR = 1.6,
            imgPath = jogglerImgpath,
            scalingRequired=false
        }
    end

    return {
            THUMB_SIZE=BASE_ICON_SIZE,
            POPUP_THUMB_SIZE=BASE_POPUP_THUMBSIZE,
            FIVE_ITEM_HEIGHT=45,
            NP_TEXT_SCALE_FACTOR = math.min(screenHeight/480, 1.4),
            NP_SPACING_FACTOR = 1.7,
            imgPath = jogglerImgpath,
            scalingRequired=false
        }
end

function getJogglerSkinParams(skinName)
    local skinValues = {
        TITLE_HEIGHT = scaleTextValue(65),
        TEXTMENU_FONT_SIZE = scaleTextValue(25),
    }
    -- before scaling update values from json config
    if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].jogglerSkin then
        local jd = jsonData[resolutionKey].jogglerSkin
        for k,_ in pairs(skinValues) do
            if jd[k] then
                log:info("using configured values of ", k , "=", jd[k], " instead of coded value ", skinValues[k])
                skinValues[k] = jd[k]
            end
        end
    end
    local params = _getJogglerCoreParams(skinName, skinValues)
    log:debug("skin core params:", table.stringify(params))

--    params.TITLE_PADDING  = { 0, 15, 0, 15 }
--    params.CHECK_PADDING  = { 2, 0, 6, 0 }
--    params.CHECKBOX_RADIO_PADDING  = { 2, 0, 0, 0 }

--    params.MENU_ITEM_ICON_PADDING = { 0, 0, 8, 0 }
----	params.MENU_PLAYLISTITEM_TEXT_PADDING = { 16, 1, 9, 1 }

----	params.MENU_CURRENTALBUM_TEXT_PADDING = { 6, 20, 0, 10 }
--    params.TEXTAREA_PADDING = { 13, 8, 8, 0 }

    params.TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
    params.TEXT_COLOR_BLACK = { 0x00, 0x00, 0x00 }
    params.TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }
    params.TEXT_COLOR_TEAL = { 0, 0xbe, 0xbe }

----	params.SELECT_COLOR = { 0xE7, 0xE7, 0xE7 }
----	params.SELECT_SH_COLOR = { }


    params.TITLE_HEIGHT = skinValues.TITLE_HEIGHT
    params.TITLE_FONT_SIZE = scaleTextValue(20)
    params.TEXTMENU_FONT_SIZE = skinValues.TEXTMENU_FONT_SIZE
    params.TITLEBAR_FONT_SIZE = scaleTextValue(28)
    params.TITLEBAR_H = scaleTextValue(28 + 4)

    params.ALBUMMENU_FONT_SIZE = scaleTextValue(20)
    params.ALBUMMENU_H = params.ALBUMMENU_FONT_SIZE + 2
    params.ALBUMMENU_SMALL_FONT_SIZE = scaleTextValue(16)

    params.POPUP_TEXT_SIZE_1 = scaleTextValue(26)
    params.POPUP_TEXT_SIZE_2 = scaleTextValue(26)
--  params.TRACK_FONT_SIZE = scaleTextValue(18)
    params.TEXTAREA_FONT_SIZE = scaleTextValue(18)
--  params.CENTERED_TEXTAREA_FONT_SIZE = scaleTextValue(28)

    params.CM_MENU_HEIGHT = 45

    params.TEXTINPUT_FONT_SIZE = 60
    params.TEXTINPUT_SELECTED_FONT_SIZE = 68


    params.HELP_FONT_SIZE = scaleTextValue(18)
    params.UPDATE_SUBTEXT_SIZE = scaleTextValue(20)

    params.ITEM_ICON_ALIGN   = 'center'
    params.ITEM_LEFT_PADDING = scaleTextValue(12)

    -- three item component vertical dimension is 72 for *ALL* skins
    params.THREE_ITEM_HEIGHT = 72

    params.TITLE_BUTTON_WIDTH = 76

    params.AUDIO_METADATA_FONT_HEIGHT = 14

    params.TEXT_BLOCK_BLACK_H = scaleTextValue(300)
    params.TEXT_BLOCK_BLACK_FONT_SIZE = scaleTextValue(300)

    params.ITEM_INFO_FONT_SIZE = scaleTextValue(14)
    params.ITEM_INFO_BOLD_FONT_SIZE = scaleTextValue(14)

    params.MULTILINE_TEXT_H = scaleTextValue(21)
    params.MULTILINE_TEXT_FONT_SIZE = scaleTextValue(18)

    params.BASE_BUTTON_FONT_SIZE = scaleTextValue(16)

    params.CM_ML_TXT_HEIGHT = scaleTextValue(172)
    params.CM_ML_TXT_LINE_HEIGHT = scaleTextValue(22)
    params.CM_ML_TXT_FONT_SIZE = scaleTextValue(18)
    params.CM_ML_TXT_SCROLLBAR_H = scaleTextValue(164)

    params.TEXT_LIST_TITLE_FONT_SIZE = scaleTextValue(14)
    params.NP_LARGE_ART_TITLE_FONT_SIZE = scaleTextValue(24)

--    params.NP_TRACK_FONT_SIZE = math.floor(36 * params.NP_TEXT_SCALE_FACTOR)
    params.NP_TRACK_FONT_SIZE = params.TITLEBAR_FONT_SIZE
    params.NP_ARTISTALBUM_FONT_SIZE = math.floor(28 * params.NP_TEXT_SCALE_FACTOR)
    params.textScaleFactor = textScaleFactor
    params.imageScaleFactor = imageScaleFactor

    -- after scaling update params values from json - if they exist
    if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].jogglerSkin then
        for k,v in pairs(jsonData[resolutionKey].jogglerSkin) do
            log:info("config: setting value of ", k , " to ", v)
            params[k] = v
        end
    end
    _writeScaledData({jogglerSkin = params}, System.getUserDir() .. '/cache/JogglerSkin.json')
    log:debug("skin params:", table.stringify(params))
    return params
end


local grid_imgpath = "applets/PiGridSkin/images/"
local BASE_GRID_ICON_SIZE = 100

local function _getGridSkinCoreParams(fiveItemHeight, skinValues)
    local screenWidth, screenHeight = Framework:getScreenSize()
    local gridMenuHeight = math.floor((screenHeight - skinValues.TITLE_HEIGHT)/fiveItemHeight) * fiveItemHeight
    if Framework:getGlobalSetting("jogglerScaleUp") then
        local thumbSize = scaleImageValue(BASE_GRID_ICON_SIZE)
        local gridItemHeight = 3 * fiveItemHeight
        local gridTxtHeight = math.ceil((skinValues.ALBUMMENU_FONT_SIZE_G + skinValues.ALBUMMENU_SMALL_FONT_SIZE_G)*1.5)
        if gridItemHeight < thumbSize + gridTxtHeight then
            thumbSize = math.floor(gridItemHeight - gridTxtHeight)
        end
        if screenWidth == 720 and screenHeight == 1280 then
            return {
                    THUMB_SIZE=thumbSize,
                    GRID_ITEM_HEIGHT = gridItemHeight,
                    ITEMS_PER_LINE = math.floor(screenWidth/scaleImageValue(160)),
                    ITEM_G_YPAD = math.floor(4 * thumbSize/BASE_GRID_ICON_SIZE),
                    GRID_MENU_H = gridMenuHeight,
                    imgPath = grid_imgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        end

        -- screenHeight < 480 => scale down TBD
        if screenWidth > screenHeight and screenHeight >=480 then
            return {
                    THUMB_SIZE = thumbSize,
                    GRID_ITEM_HEIGHT =  gridItemHeight,
                    ITEMS_PER_LINE = math.floor(screenWidth/scaleImageValue(160)),
                    ITEM_G_YPAD = math.floor(4 * thumbSize/BASE_GRID_ICON_SIZE),
                    GRID_MENU_H = gridMenuHeight,
                    imgPath = grid_imgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        end
    end
    return {
            THUMB_SIZE=BASE_GRID_ICON_SIZE,
            GRID_ITEM_HEIGHT=174,
            ITEMS_PER_LINE = screenWidth/160,
            ITEM_G_YPAD = 4,
            GRID_MENU_H = gridMenuHeight,
            imgPath = grid_imgpath,
            scalingRequired=false
        }
end

function getGridSkinParams(fiveItemHeight)
    local skinValues = {
        TITLE_HEIGHT = scaleTextValue(65),
        ITEM_FONT_SIZE_G = scaleGridTextValue(28),
        ALBUMMENU_FONT_SIZE_G = scaleGridTextValue(18),
        ALBUMMENU_SMALL_FONT_SIZE_G = scaleGridTextValue(16),
    }
    -- before scaling update values from json config
    if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].gridSkin then
        local jd = jsonData[resolutionKey].gridSkin
        for k,_ in pairs(skinValues) do
            if jd[k] then
                log:info("using configured values of ", k , "=", jd[k], " instead of coded value ", skinValues[k])
                skinValues[k] = jd[k]
            end
        end
    end
    local params = _getGridSkinCoreParams(fiveItemHeight, skinValues)
    log:debug("grid skin core params:", table.stringify(params))
    for k,v in pairs(skinValues) do
        params[k] = v
    end
    params.gridTextScaleFactor = gridTextScaleFactor
    -- after scaling update params values from json - if they exist
    if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].gridSkin then
        for k, v in pairs(jsonData[resolutionKey].gridSkin) do
            log:info("config: setting value of ", k , " to ", v)
            params[k] = v
        end
    end
    _writeScaledData({gridSkin = params}, System.getUserDir() .. '/cache/PiGridSkin.json')
    log:debug("grid skin params:", table.stringify(params))
    return params
end
