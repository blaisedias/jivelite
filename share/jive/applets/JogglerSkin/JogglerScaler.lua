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
local coroutine, package	= coroutine, package

-- lua package imports
local math  = require("math")
local lfs   = require("lfs")
local os    = require("os")
local io    = require("io")
local string      = require("string")

-- jive package imports
local Surface = require("jive.ui.Surface")
local log     = require("jive.utils.log").logger("applet.JogglerSkin")
local System  = require("jive.System")
local Framework     = require("jive.ui.Framework")
local json          = require("jive.json")
local table         = require("jive.utils.table")

-- package global variables
local textScaleFactor
local npTextScaleFactor
local thumbnailScaleFactor
local gridTextScaleFactor
local controlsScaleFactor
local jsonData
local resolutionKey

local BASE_ICON_SIZE = 40
local BASE_POPUP_THUMBSIZE = 120
local jogglerImgpath = "applets/JogglerSkin/images/"
local gridImgpath = "applets/PiGridSkin/images/"

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
    data["comments"] = {
        ADJUST_FOR_GRID_ROWS = {
            "values are:",
            " - rounddown -> reduced number of grid rows to fit",
            " - roundup   -> increase number of grid rows to fit",
            " - anything-else  -> display partial grid row"
        }
    }
    local jsonString = json.stringify(data)
    local fh = io.open(jsPath, "w")
    if fh then
        fh:write(jsonString)
        fh:close()
        log:debug("wrote scaled data json ", jsPath)
    end
end

function updateJsonConfig(key, skin, value)
    local jsPath = System.getUserDir() .. '/Joggler.json'
    local json_data = _loadJsonData(jsPath)
    if json_data == nil then
        json_data = { }
    end
    if json_data[resolutionKey] == nil then
        json_data[resolutionKey] = {
            jogglerSkin = {},
            gridSkin = {}
        }
    end
    json_data[resolutionKey][skin][key] = value
    local jsonString = json.stringify(json_data)
    local fh = io.open(jsPath, "w")
    if fh then
        fh:write(jsonString)
        fh:close()
        log:debug("wrote scaled data json ", jsPath)
    end
end

function deleteAllScaledUIImages()
    local dest_path = System.getUserDir() .. '/' .. jogglerImgpath
    log:debug('rm -rf ' .. dest_path)
    os.execute('rm -rf ' .. dest_path)
    dest_path = System.getUserDir() .. '/' ..  gridImgpath
    log:debug('rm -rf ' .. dest_path)
    os.execute('rm -rf ' .. dest_path)
end

-- reset static variables so that determination of scaling values
-- proceeds afresh
function initialise()
    textScaleFactor = nil
    thumbnailScaleFactor = nil
    gridTextScaleFactor = nil
    controlsScaleFactor = nil
    jsonData = nil
    resolutionKey = nil

    local screenWidth, screenHeight = Framework:getScreenSize()
    resolutionKey = screenWidth .. 'x' .. screenHeight
    jsonData = _loadJsonData(System.getUserDir() .. '/Joggler.json')
    if jsonData and jsonData[resolutionKey] then
        local jd = jsonData[resolutionKey]['jogglerSkin']
        if jd ~= nil then
            textScaleFactor = jd.textScaleFactor
            npTextScaleFactor = jd.npTextScaleFactor
            thumbnailScaleFactor = jd.thumbnailScaleFactor
            controlsScaleFactor = jd.controlsScaleFactor
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
        if Framework:getGlobalSetting("jogglerScaleAndCustomise") and screenHeight > 480 then
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

--  function scale a NowPlaying screen text size value to match the display dimensions
function scaleNPTextValue(v)
    if npTextScaleFactor == nil then
        -- default to scaling of 1
        npTextScaleFactor = 1
        local screenWidth, screenHeight = Framework:getScreenSize()
        if Framework:getGlobalSetting("jogglerScaleAndCustomise") and screenHeight > 480 then
            -- landscape
            if screenWidth > screenHeight then
                if screenHeight >= 480 then
                    npTextScaleFactor = screenHeight / 480
                else
                    if screenWidth/screenHeight >= 3 then
                        npTextScaleFactor = 1
                    else
                        npTextScaleFactor =  math.max(screenHeight/480, 0.8)
                    end
                end
            end
            -- portrait
--            for now only explicitly support portrait mode 720x1280
            if screenWidth == 720 and screenHeight == 1280 then
                npTextScaleFactor = 1.4
            end
        end
    end
    return math.floor(npTextScaleFactor * v)
end


-- global function scale a text size value to match the display dimensions for grid items
function scaleGridTextValue(v)
    if gridTextScaleFactor == nil then
        -- default to scaling of 1
        gridTextScaleFactor = 1
        if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
            local screenWidth, screenHeight = Framework:getScreenSize()
            if screenHeight > 480 then
                if screenWidth > screenHeight then
                    gridTextScaleFactor = ((screenHeight * 0.0008333333333333334) + 0.6)
                else
                    -- portrait mode the same for now
                    gridTextScaleFactor = ((screenWidth * 0.0008333333333333334) + 0.6)
                end
            end
        end
    end
    return math.floor(gridTextScaleFactor * v)
end

-- global function scale an image size value to match the display dimensions
function scaleThumbsizeValue(v)
    if thumbnailScaleFactor == nil then
        -- default to scaling of 1
        thumbnailScaleFactor = 1
        if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
            local screenWidth, screenHeight = Framework:getScreenSize()
            -- landscape
            if screenWidth > screenHeight then
                thumbnailScaleFactor = screenHeight / 480
            end
            -- portrait
--            if screenWidth < screenHeight then
--                thumbnailScaleFactor = screenWidth / 800
--            end
--            for now only explicitly support portrait mode 720x1280
            if screenWidth == 720 and screenHeight == 1280 then
                thumbnailScaleFactor = screenWidth / 480
            end
        end
    end
    return math.floor(thumbnailScaleFactor * v)
end

-- function scale an controls image size value to match the display dimensions
local function scaleControlsImageValue(v)
    if controlsScaleFactor == nil then
        -- default to scaling of 1
        controlsScaleFactor = 1
        local screenWidth, screenHeight = Framework:getScreenSize()
        if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
            -- By default do not scale controls down
            if screenHeight >= 480 then
                -- landscape
                if screenWidth > screenHeight then
                    controlsScaleFactor = screenHeight / 480
                end
                -- portrait
                if screenWidth < screenHeight then
                    controlsScaleFactor = (screenWidth / 800) * 1.6666666666666665
                end
            end
        end
    end
    return math.floor(controlsScaleFactor * v)
end

-- private function scales an image to match input width and height
-- if either one but not both are nil, then the corresponding source image dimension is used.
-- if either one but not both are 0, then the value used for the dimension retains the source aspect ratio
local function scaleImage(imgPath, w, h)
    log:debug("scaleImage imagePath:", imgPath, " w:", w, " h:", h)
    local img = Surface:altLoadImage(imgPath)
    if img == nil then
        log:warn("scaleImage: failed to load ", imgPath)
        return nil
    end
    local srcW, srcH = img:getSize()
    -- validate input parameters and bail out gracefully
    if (w == nil or h == 0) and ( h == nil or h == 0) then
        log:warn("scaleImage: invalid parameters ", imgPath)
        return nil
    end
    if w == nil then
        w = srcW
    elseif w == 0 then
        w = math.floor(srcW * h/srcH)
    end
    if h == nil then
        h = srcH
    elseif h == 0 then
        h = math.floor(srcH * h/srcW)
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

-- private function scales a image in a file and saves as an image in another file
local function scaleImageFile(src_path, dest_path, w, h)
            local mode = lfs.attributes(src_path, "mode")
            if mode == "file" then
                mode = lfs.attributes(dest_path, "mode")
                if mode ~= "file"  then
                    log:info(src_path .. ' -> ' .. dest_path)
                    local img = scaleImage(src_path, w, h)
                    if img ~= nil then
                        img:savePNG(dest_path)
                        img:release()
                    else
                        log:warn("failed to scale ", src_path)
                    end
                end
            else
                log:warn("image file not found: ", src_path)
            end
end

local function str_endswith(str, ending)
    return ending == "" or string.sub(str, -#ending) == ending
end

local function pathIter(rpath)
	local hist = {}
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		if hist[dir] == nil then
			hist[dir] = true
			-- only search in the jivelite lua source tree
			-- we could pass in a filter function but this is good enough
--			if dir ~= "./" and str_endswith(dir, '/jivelite/share/jive/') then
			if str_endswith(dir, '/jivelite/share/jive/') then
				dir = dir .. rpath
				local mode = lfs.attributes(dir, "mode")
				if mode == "directory" then
					coroutine.yield(dir)
				end
			end
		end
	end
end

local function findPaths(rpath)
	local co = coroutine.create(function() pathIter(rpath) end)
	return function()
		local _, res = coroutine.resume(co)
		return res
	end
end

function scaleControlsImages(params)
    local controls_resize_map = {
        {
            -- control popup images
            dim = params.CONTROL_POPUP_DIMENSIONS,
            imgs = {
                { src="skip-next.png", dest="icon_popup_box_fwd.png"},
                { src="pause-circle.png", dest="icon_popup_box_pause.png"},
                { src="play-circle.png", dest="icon_popup_box_play.png"},
                { src="repeat-off-5-variant.png", dest="icon_popup_box_repeat_off.png"},
                { src="repeat-variant.png", dest="icon_popup_box_repeat.png"},
                { src="repeat-once-variant.png", dest="icon_popup_box_repeat_song.png"},
                { src="skip-previous.png", dest="icon_popup_box_rew.png"},
                { src="shuffle-album.png", dest="icon_popup_box_shuffle_album.png"},
                { src="shuffle-disabled.png", dest="icon_popup_box_shuffle_off.png"},
                { src="shuffle.png", dest="icon_popup_box_shuffle.png"},
            },
        },
        {
            -- button pressed background
            dim = params.CONTROLS_DIMENSIONS,
            imgs = {
                { src="control_keyboard_button_press.png", dest="control_keyboard_button_press.png"}
            },
        },
        {
            -- control buttons
            dim = math.ceil(params.CONTROLS_DIMENSIONS * 0.64),
            imgs = {
                { src="skip-next.png", dest="icon_toolbar_ffwd.png", },
                { src="DIS-skip-next.png", dest="icon_toolbar_ffwd_dis.png", },
                { src="pause-circle.png", dest="icon_toolbar_pause.png", },
                { src="play-circle.png", dest="icon_toolbar_play.png", },
                { src="repeat-off-5-variant.png", dest="icon_toolbar_repeat_off.png", },
                { src="repeat-variant.png", dest="icon_toolbar_repeat_on.png", },
                { src="repeat-once-variant.png", dest="icon_toolbar_repeat_song_on.png", },
                { src="skip-previous.png", dest="icon_toolbar_rew.png", },
                { src="shuffle-album.png", dest="icon_toolbar_shuffle_album_on.png", },
                { src="DIS-shuffle-disabled.png", dest="icon_toolbar_shuffle_dis.png", },
                { src="shuffle-disabled.png", dest="icon_toolbar_shuffle_off.png", },
                { src="shuffle.png", dest="icon_toolbar_shuffle_on.png", },
                { src="next-visualiser.png", dest="icon_toolbar_twiddle.png", },
            },
        },
        {
            -- volume control buttons
            dim = math.ceil(params.CONTROLS_DIMENSIONS * 0.5),
            imgs = {
                { src="DIS-volume-minus.png", dest="icon_toolbar_vol_down_dis.png", },
                { src="volume-minus.png", dest="icon_toolbar_vol_down.png", },
                { src="DIS-volume-plus.png", dest="icon_toolbar_vol_up_dis.png", },
                { src="volume-plus.png", dest="icon_toolbar_vol_up.png", },
            },
        }
    }

    local src_path = nil
    for pth in findPaths("applets/JogglerSkin/images/UNOFFICIAL/Material/Icons/1k") do
        src_path = pth
    end

    if src_path == nil or (lfs.attributes(src_path, "mode") ~= "directory") then
        log:error("scaleControlsImages: ", src_path, " is not a directory")
        return
    end

    local dest_path = System.getUserDir() .. '/applets/JogglerSkin/images/UNOFFICIAL/Material/Icons/' .. params.CONTROLS_DIMENSIONS
    os.execute("mkdir -p " .. dest_path)
    for _, v in pairs(controls_resize_map) do
        local dim = v.dim
        for _, imgnames in pairs(v.imgs) do
            scaleImageFile(src_path .. "/" .. imgnames.src, dest_path .. "/" .. imgnames.dest, dim, dim)
        end
    end

    -- scale volume bar components
    local vol_dim = math.ceil(params.CONTROLS_DIMENSIONS * 0.5)
    for pth in findPaths("applets/JogglerSkin/images/UNOFFICIAL/Material/VolumeBar/1k") do
        src_path = pth
    end

    if src_path == nil or (lfs.attributes(src_path, "mode") ~= "directory") then
        log:error("scaleControlsImages: ", src_path, " is not a directory")
        return
    end
    dest_path = System.getUserDir() .. '/applets/JogglerSkin/images/UNOFFICIAL/Material/VolumeBar/' .. params.CONTROLS_DIMENSIONS
    os.execute("mkdir -p " .. dest_path)
    scaleImageFile(src_path .. '/' .. 'tch_volumebar_fill_l.png', dest_path .. '/' .. 'tch_volumebar_fill_l.png', 0, vol_dim)
    scaleImageFile(src_path .. '/' .. 'tch_volumebar_fill_r.png', dest_path .. '/' .. 'tch_volumebar_fill_r.png', 0, vol_dim)
    scaleImageFile(src_path .. '/' .. 'tch_volumebar_fill.png', dest_path .. '/' .. 'tch_volumebar_fill.png', vol_dim*9, vol_dim)
    scaleImageFile(src_path .. '/' .. 'tch_volumebar_slider.png', dest_path .. '/' .. 'tch_volumebar_slider.png', 0, vol_dim)
end


-- global function scale images required for Joggler based skins
function scaleUIImages(imgs_path, params)
    local resizedPath = System.getUserDir() .. '/' .. params.imgPath
    os.execute("mkdir -p " .. resizedPath .. '/grid_list')
    os.execute("mkdir -p " .. resizedPath .. '/5_line_lists')
    os.execute("mkdir -p " .. resizedPath .. '/IconsResized')
    os.execute("mkdir -p " .. resizedPath .. '/Buttons')

    local fq_imgs_path = nil
    for pth in findPaths(imgs_path) do
        fq_imgs_path = pth
    end
    log:info("scaleUIImages ", imgs_path, " == ", fq_imgs_path , " -> ", resizedPath)
    if fq_imgs_path == nil or (lfs.attributes(fq_imgs_path, "mode") ~= "directory") then
        log:error("scaleUIImages: ", fq_imgs_path, " is not a directory")
        return
    end

    if params.GRID_ITEM_HEIGHT ~= nil then
        scaleImagesInPath(
            fq_imgs_path .. "/grid_list",
            resizedPath .. '/grid_list',
            nil,
            params.GRID_ITEM_HEIGHT
         )
    end

    if params.FIVE_ITEM_HEIGHT ~= nil then
        scaleImagesInPath(
            fq_imgs_path .. "/5_line_lists",
            resizedPath .. '/5_line_lists',
            nil,
            params.FIVE_ITEM_HEIGHT
         )
    end

    scaleImagesInPath(
        fq_imgs_path .. "/IconsResized",
        resizedPath .. '/IconsResized',
        params.THUMB_SIZE,
        params.THUMB_SIZE
    )

    scaleImagesInPath(
        fq_imgs_path .. "/Buttons",
        resizedPath .. '/Buttons',
        nil,
        params.TITLE_HEIGHT - 18
    )
end

local function _getJogglerCoreParams(skinName, skinValues)
    local screenWidth, screenHeight = Framework:getScreenSize()
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
--        if controlsScaleFactor == nil then
--            controlsScaleFactor = skinValues.TITLE_HEIGHT/70
--        end
        -- Heuristic for "ultra wide" screens with height < 480
        if skinName == "PiGridSkin" and screenHeight < 480 and screenWidth/screenHeight >= 3 then
            if thumbnailScaleFactor == nil then
                log:debug("PiGridSkin: ultra wide screen with height < 480,  override thumbnailScaleFactor to 1")
                thumbnailScaleFactor = 1
            end
        end
        -- padding at the bottom is nominally 16
        local availHeight = screenHeight - skinValues.TITLE_HEIGHT - 16
        local fiveItemHeight = math.floor(availHeight/math.floor(availHeight/(skinValues.TEXTMENU_FONT_SIZE * 1.8)))
        local rows =  math.floor(availHeight/fiveItemHeight)
        local TEXTMENU_FONT_SIZE = skinValues.TEXTMENU_FONT_SIZE
        if skinName == "PiGridSkin" then
            if rows % 3 ~= 0 then
                -- grid item height = 3 * fiveItemHeight,
                -- For now: PiGridSkin scrolling needs more than 1 row so force roundup
                if skinValues.ADJUST_FOR_GRID_ROWS == "roundup" or (math.floor(rows/3)*3) == 3 then
                -- increase the number of rows to be a multiple of 3
                    rows = math.floor((rows+2)/3)*3
                elseif skinValues.ADJUST_FOR_GRID_ROWS == "rounddown" then
                -- decrease the number of rows to be a multiple of 3
                    rows = math.floor(rows/3)*3
                end
                log:info("fiveItemHeight adjusted for PiGridSkin requirements ",
                            fiveItemHeight, ' -> ', math.floor(availHeight/rows)
                        )
                -- recalculate fiveItemHeight using the adjusted number of rows
                fiveItemHeight = math.floor(availHeight/rows)
                -- change associated text menu size to match updated fiveItemHeight
                TEXTMENU_FONT_SIZE = math.floor(fiveItemHeight/1.8)
            end
        end
        -- visually, fuzzy padding at the bottom is better, sacrifice up to X pixels,
        -- if we can increment fiveItemHeight by 1
        if availHeight%(rows * fiveItemHeight) + 7 >= rows then
            fiveItemHeight = fiveItemHeight + 1
            -- change associated text menu size to match updated fiveItemHeight
            TEXTMENU_FONT_SIZE = math.floor(fiveItemHeight/1.8)
        end
        local popupThumbSize = scaleThumbsizeValue(BASE_POPUP_THUMBSIZE)
        if screenWidth == 720 and screenHeight == 1280 then
            local thumbSize = 72
            skinValues.TEXTMENU_FONT_SIZE = TEXTMENU_FONT_SIZE
            return {
                    THUMB_SIZE=thumbSize,
                    POPUP_THUMB_SIZE=popupThumbSize,
                    FIVE_ITEM_HEIGHT=fiveItemHeight,
                    NP_LINE_SPACING = 1.7,
                    CONTROLS_DIMENSIONS = scaleControlsImageValue(70),
                    CONTROL_POPUP_DIMENSIONS = math.floor(screenWidth * 0.20),
                    imgPath = jogglerImgpath .. thumbSize .. "/",
                    scalingRequired=true
                }
        elseif screenWidth > screenHeight and screenHeight >480 then
            local thumbSize = scaleThumbsizeValue(BASE_ICON_SIZE)
            skinValues.TEXTMENU_FONT_SIZE = TEXTMENU_FONT_SIZE
            return {
                    THUMB_SIZE=thumbSize,
                    POPUP_THUMB_SIZE=popupThumbSize,
                    FIVE_ITEM_HEIGHT=fiveItemHeight,
                    NP_LINE_SPACING = 1.9,
                    CONTROLS_DIMENSIONS = scaleControlsImageValue(70),
                    CONTROL_POPUP_DIMENSIONS = math.floor(screenHeight * 0.20),
                    imgPath = jogglerImgpath .. thumbSize .. "/",
                    scalingRequired=true
                }
       -- screenHeight < 480 => scale down
       elseif screenHeight < 480 then
            local thumbSize = scaleThumbsizeValue(BASE_ICON_SIZE)
            skinValues.TEXTMENU_FONT_SIZE = TEXTMENU_FONT_SIZE
            if screenWidth/screenHeight >= 3 then
                return {
                    THUMB_SIZE=thumbSize,
                    POPUP_THUMB_SIZE=popupThumbSize,
                    FIVE_ITEM_HEIGHT=fiveItemHeight,
                    NP_LINE_SPACING = 1.9,
                    CONTROLS_DIMENSIONS = scaleControlsImageValue(70),
                    CONTROL_POPUP_DIMENSIONS = math.floor(screenHeight * 0.20),
                    imgPath = jogglerImgpath .. thumbSize .. "/",
                    scalingRequired=true
                }
            end
            return {
                THUMB_SIZE=thumbSize,
                POPUP_THUMB_SIZE=popupThumbSize,
                FIVE_ITEM_HEIGHT=fiveItemHeight,
                NP_LINE_SPACING = 1.6,
                CONTROLS_DIMENSIONS = scaleControlsImageValue(70),
                CONTROL_POPUP_DIMENSIONS = math.floor(screenHeight * 0.20),
                imgPath = jogglerImgpath .. thumbSize .. "/",
                scalingRequired=true
            }
        end
    end

    return {
            THUMB_SIZE=BASE_ICON_SIZE,
            POPUP_THUMB_SIZE=BASE_POPUP_THUMBSIZE,
            FIVE_ITEM_HEIGHT=45,
            NP_LINE_SPACING = 1.7,
            CONTROLS_DIMENSIONS = 70,
            CONTROL_POPUP_DIMENSIONS = 146,
            imgPath = jogglerImgpath,
            scalingRequired=false
        }
end

function getJogglerSkinParams(skinName)
    local skinValues = {
        TITLE_HEIGHT = scaleTextValue(65),
        TEXTMENU_FONT_SIZE = scaleTextValue(25),
        -- hint for adjusting FIVE_ITEM_HEIGHT for PiGridSkin
        --  rounddown -> increase FIVE_ITEM_HEIGHT to reduce the number of Grid Item Rows
        --  roundup -> decrease FIVE_ITEM_HEIGHT to increase the number of Grid Item Rows
        --  * -> no adjustment - bottom Grid Item Row may be rendered partially
        ADJUST_FOR_GRID_ROWS = "rounddown",
    }
    -- before scaling update values from json config
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
        if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].jogglerSkin then
            local jd = jsonData[resolutionKey].jogglerSkin
            for k,_ in pairs(skinValues) do
                if jd[k] then
                    log:info("using configured values of ", k , "=", jd[k], " instead of coded value ", skinValues[k])
                    skinValues[k] = jd[k]
                end
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
    params.TEXT_COLOR_DC = { 0xDC, 0xDC, 0xDC }
    params.TEXT_COLOR_BB = { 0xBB, 0xBB, 0xBB }
--    params.TEXT_COLOR_B3 = { 0xB3, 0xB3, 0xB3 }
    params.TEXT_COLOR_DISABLED = { 0x66, 0x66, 0x66 }
    params.TEXT_COLOR_YELLOW = { 0xbe, 0xbe, 0 }
    params.TEXT_COLOR_PURPLE = { 0xbe, 0, 0xbe }

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
    params.NP_TRACKLAYOUT_ALIGN = 'center'
    params.NP_PROGRESSNB_ALIGN = 'left'

--    params.NP_TRACK_FONT_SIZE = params.TITLEBAR_FONT_SIZE
--    params.NP_TRACK_FONT_SIZE =  scaleNPTextValue(28)
    params.NP_TRACK_FONT_SIZE = scaleNPTextValue(36)
    params.NP_ARTISTALBUM_FONT_SIZE = scaleNPTextValue(28)
    if true then
        local screenWidth, screenHeight = Framework:getScreenSize()
        if screenWidth/screenHeight >= 3 then
            local availHeight = screenHeight - skinValues.TITLE_HEIGHT - 16 - 50
            -- When screen apect ratio is > 3 then visualisers are positioned to the right
            -- instead of below.
            -- Increase size of fonts used for track information to use empty space below.
            -- Heuristic
            params.NP_ARTISTALBUM_FONT_SIZE = math.floor(availHeight/5.5)
            params.NP_TRACK_FONT_SIZE = math.floor(availHeight/5.5)
        end
    end

    params.textScaleFactor = textScaleFactor
    params.npTextScaleFactor = npTextScaleFactor
    params.thumbnailScaleFactor = thumbnailScaleFactor
    params.gridTextScaleFactor = gridTextScaleFactor
    params.controlsScaleFactor = controlsScaleFactor

    -- after scaling update params values from json - if they exist
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
        if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].jogglerSkin then
            for k,v in pairs(jsonData[resolutionKey].jogglerSkin) do
                log:info("config: setting value of ", k , " to ", v)
                params[k] = v
            end
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
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
        local thumbSize = scaleThumbsizeValue(BASE_GRID_ICON_SIZE)
        local gridItemHeight = 3 * fiveItemHeight
        local gridTxtHeight = math.ceil((skinValues.ALBUMMENU_FONT_SIZE_G + skinValues.ALBUMMENU_SMALL_FONT_SIZE_G)*1.5)
        if gridItemHeight < thumbSize + gridTxtHeight then
            thumbSize = math.floor(gridItemHeight - gridTxtHeight)
        end
        if screenWidth == 720 and screenHeight == 1280 then
            return {
                    THUMB_SIZE=thumbSize,
                    GRID_ITEM_HEIGHT = gridItemHeight,
                    ITEMS_PER_LINE = math.floor(screenWidth/scaleThumbsizeValue(160)),
                    ITEM_G_YPAD = math.floor(4 * thumbSize/BASE_GRID_ICON_SIZE),
                    GRID_MENU_H = gridMenuHeight,
                    imgPath = grid_imgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        elseif screenWidth > screenHeight and screenHeight >480 then
            return {
                    THUMB_SIZE = thumbSize,
                    GRID_ITEM_HEIGHT =  gridItemHeight,
                    ITEMS_PER_LINE = math.floor(screenWidth/scaleThumbsizeValue(160)),
                    ITEM_G_YPAD = math.floor(4 * thumbSize/BASE_GRID_ICON_SIZE),
                    GRID_MENU_H = gridMenuHeight,
                    imgPath = grid_imgpath .. thumbSize .. "/",
                    scalingRequired=true
            }
        elseif screenWidth/screenHeight >=3 and screenHeight <480 then
            return {
                    THUMB_SIZE = thumbSize,
                    GRID_ITEM_HEIGHT =  gridItemHeight,
                    ITEMS_PER_LINE = math.floor(screenWidth/scaleThumbsizeValue(160)),
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
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
        if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].gridSkin then
            local jd = jsonData[resolutionKey].gridSkin
            for k,_ in pairs(skinValues) do
                if jd[k] then
                    log:info("using configured values of ", k , "=", jd[k], " instead of coded value ", skinValues[k])
                    skinValues[k] = jd[k]
                end
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
    if Framework:getGlobalSetting("jogglerScaleAndCustomise") then
        if jsonData and jsonData[resolutionKey] and jsonData[resolutionKey].gridSkin then
            for k, v in pairs(jsonData[resolutionKey].gridSkin) do
                log:info("config: setting value of ", k , " to ", v)
                params[k] = v
            end
        end
    end
    _writeScaledData({gridSkin = params}, System.getUserDir() .. '/cache/PiGridSkin.json')
    log:debug("grid skin params:", table.stringify(params))
    return params
end
