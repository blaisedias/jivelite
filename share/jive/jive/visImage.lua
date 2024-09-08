 --[[
 =head1 NAME

 jive.visImage - visualiser support

 =head1 DESCRIPTION

 Implements visualiser support
  - menu selection support
  - resize for multiple resoultions
  - image caching
  - ....

 (c) Blaise Dias, 2023

 =cut
 --]]

--
-- lua package imports
local math	= require("math")
local table	= require("table")
local lfs	= require("lfs")
local os	= require("os")
local io	= require("io")

--local ipairs, pairs = ipairs, pairs
local pairs = pairs
local coroutine, package	= coroutine, package

-- jive package imports
local string		= require("jive.utils.string")
local Surface		= require("jive.ui.Surface")
--local vis			= require("jive.vis")
--local debug		 	= require("jive.utils.debug")
local log			= require("jive.utils.log").logger("jivelite.vis")
local System		= require("jive.System")
local FRAME_RATE    = jive.ui.FRAME_RATE

module(...)

-- Spectrum visualisation types
--local SPT_DEFAULT = "default"
local SPT_BACKLIT = "backlit"
local SPT_IMAGE = "image"
local SPT_COLOUR = "colour"

local vuImages = {}
local spectrumList = {}
local vuSeq = {}
local spSeq = {}
local visSettings = {}

-- commit resized images to disk
local saveResizedImages = true
local saveimage_type = "png"
-- resized images table this table is populated on startup by searching for files
-- at pre-defined locations.
-- It is used to determine if a particular resized image exists,
-- so that unnecessary expensive resize operations are not repeated.
-- In that sense it is a bit like a cache.
local resizedImagesTable = {}
local displayResizingParameters = {}

local PLATFORM = ""
-- PCP only
local persistent_storage_root = nil

-- on desktop OSes userPath is persistent
local defaultWorkspace = System.getUserDir()
local workSpace = defaultWorkspace
local resizedCachePath = workSpace .. "/cache/resized"

local function _parseImagePath(imgpath)
	local parts = string.split("%.", imgpath)
	local ix = #parts
	if parts[ix] == 'png' or parts[ix] == 'jpg' or parts[ix] == 'bmp' then
-- FIXME return array of size 2 always
		return parts
	end
	return nil
end

local function boolOsEnv(envName, defaultValue)
	local tmp = os.getenv(envName)
	log:info("boolOsEnv:", envName, " defaultValue:", defaultValue, " got:", tmp)
	if tmp ~= nil then
		if defaultValue then
			if tmp == "0" or tmp == "false" or tmp ~= "False" then
				log:info("boolOsEnv: -> false")
				return false
			end
		else
			if tmp == "1" or tmp == "true" or tmp ~= "True" then
				log:info("boolOsEnv: -> true")
				return true
			end
		end
	end
	log:info("boolOsEnv: returning defaultValue: ", defaultValue)
	return defaultValue
end

local function ShuffleInPlace(t)
	if visSettings.randomSequence == true then
		for i = #t, 2, -1 do
			local j = math.random(i)
			t[i], t[j] = t[j], t[i]
		end
	end
end

--------------------------------------------------------
--- platform
--------------------------------------------------------
-- at the moment the only distinction is pcp or desktop
local function platformDetect()
	if PLATFORM ~= "" then
		return PLATFORM
	end
	PLATFORM = "desktop"

	-- if setting is absent fall back to legacy behaviour
	if visSettings.saveAsPng == nil then
		visSettings.saveAsPng = boolOsEnv("JL_SAVE_AS_PNG", true)
	end
	if visSettings.saveAsPng == false then
		saveimage_type = 'bmp'
	end

	-- if setting is absent fall back to legacy behaviour
	if visSettings.saveResizedImages == nil then
		visSettings.saveResizedImages = boolOsEnv("JL_SAVE_RESIZED_IMAGES", true)
	end
	saveResizedImages = visSettings.saveResizedImages

	-- Support saving resized visualiser images
	-- in locations other then the home directory
	-- defining a path to a workspace is supported
	local wkSpace = visSettings.workSpace

	-- legacy compatability:
	-- if workspace is absent from settings and environment variable is set
	-- use the environment variable
	if wkSpace == nil or string.len(wkSpace) == 0 then
		wkSpace = os.getenv("JL_WORKSPACE")
	end

	-- workspace on PCP has additional requirements,
	-- must be under persistent storage root
	local pcp_version_file = "/usr/local/etc/pcp/pcpversion.cfg"
	local mode = lfs.attributes(pcp_version_file, "mode")
	if mode == "file" then
		PLATFORM = "piCorePlayer"
		persistent_storage_root = io.popen('readlink /etc/sysconfig/tcedir'):read()
	end

	visSettings.persisentStorageRoot =  persistent_storage_root

	if wkSpace ~= nil and string.len(wkSpace) ~= 0 then
		workSpace = wkSpace
		resizedCachePath = workSpace .. "/cache/resized"
	end

	os.execute("mkdir -p " .. resizedCachePath)
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/spectrum/gradient")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/spectrum/backlit")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters/25frames")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters/25framesLR")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters/vfd")

	log:info("PLATFORM:", PLATFORM, " workSpace:" , workSpace, " resizedCachePath:", resizedCachePath)
	log:info("saveResizedImages:", saveResizedImages, " save image type:" , saveimage_type)
	return PLATFORM
end

--------------------------------------------------------
--- in memory image cache(s)
--------------------------------------------------------

-- FIXME: vfdCache should go through imCache
local vfdCache = {}
local imCache = {}

local function imCachePut(key, img)
	log:info("imCache <- ", key,  " ", img)
	imCache[key] = img
end

local function imCacheGet(key)
	local img = imCache[key]
	if img ~= nil then
		log:info("imCache -> ", key,  " ", img)
	else
		log:info("imCache X ", key)
	end
	return img
end

local function imCacheClear()
	log:info("imCacheClear")
	vfdCache = {}
	for k,v in pairs(imCache) do
		log:info("releasing ", k)
		v:altRelease()
	end
	imCache={}
end

local function loadImage(path)
	local img = imCacheGet(path)
	if img == nil  then
		if path == nil then
			return nil
		end
		img = Surface:altLoadImage(path)
		imCachePut(path, img)
	end
	return img
end

local function loadResizedImage(key)
	local path = resizedImagesTable[key]
	if path ~= nil then
		return loadImage(path)
	end
	return nil
end

-- when a resized image is saved
--  update the table so that it can be found subsequently
local function saveImage(img, key, path)
	if img == nil or key == nil or path == nil then
		log:error("saveImage got nil parameter img=", img, " key=", key, " path=", path)
		return
	end
	if saveResizedImages then
		if saveimage_type == "png" then
			img:savePNG(path)
			resizedImagesTable[key] = path
		elseif saveimage_type == "bmp" then
			img:saveBMP(path)
			resizedImagesTable[key] = path
		else
			log:error('unsupported image type: ', saveimage_type)
		end
	end
end

--------------------------------------------------------
--- resized images hashtable
--------------------------------------------------------
-- debug function
function dumpResizedImagesTable()
	log:info("dumpResizedImagesTable")
	for k,v in pairs(resizedImagesTable) do
		log:info("    ", k, " -> ", v)
	end
	log:info("\n\n")
end

-- function getImageName(imgPath)
-- 	local fullpath = string.split("/", imgPath)
-- 	local name = fullpath[#fullpath]
-- 	local parts = string.split("%.", name)
-- 	return parts[1]
-- end

local function pathIter(rpath)
	local hist = {}
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		if hist[dir] == nil then
			hist[dir] = true
			if dir ~= "./" then
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

local function resizedImagePath(name)
	-- we don't know/care whether it is a bmp, png or jpeg
	-- saving and loading the file just works
	local file = resizedCachePath .. "/" .. name .. "." .. saveimage_type
	return file
end

-- function cacheClear(_)
-- 	log:debug("cacheClear ")
-- 	for k,v in pairs(resizedImagesTable) do
-- 		log:debug("cacheClear ", k)
-- 		resizedImagesTable[k] = nil
-- 	end
-- --	resizedImagesTable = {}
-- 	imCacheClear()
-- end

function deleteResizedImages(_)
	log:info("deleteResizedImages ")
	for k,v in pairs(resizedImagesTable) do
		log:info("deleteResizedImages ", k, " ", v)
		os.execute('rm  ' .. '"'.. v .. '"')
		resizedImagesTable[k] = nil
	end
--	resizedImagesTable = {}
	imCacheClear()
end


local function _populateResizedImagesTable(search_root)
	log:info("_populateResizedImagesTable", " ", search_root)

	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				resizedImagesTable[parts[1]] = search_root .. "/" .. entry
				log:debug("_populateResizedImagesTable: ", parts[1], " ", resizedImagesTable[parts[1]])
			end
		end
	end
end

-- return a shallow copy of displayResizingParameters if resize is required
local function makeResizingParams(resizeIsRequired)
	if displayResizingParameters ~= nil and resizeIsRequired then
		local w, _ = displayResizingParameters.img:getSize()
-- hard coded to width of 150
		local f = math.floor(w/150)
		return {
			img = displayResizingParameters.img,
			h = displayResizingParameters.h,
			w = displayResizingParameters.w/f,
			-- rendered frame counter
			c = 0,
			-- rendered frame counter divisior
			d = math.floor(FRAME_RATE/f),
			-- rendered frame counter maximum
			m = math.floor(FRAME_RATE/f) * f,
		}
	end
	return nil
end

--------------------------------------------------------
--- image scaling
--------------------------------------------------------

--------------------------------------------------------
--- Spectrum
--------------------------------------------------------
local spImageIndex = 1
local spectrumImagesMap = {}
local spectrumResolutions = {}

function registerSpectrumResolution(_, w,h)
	log:debug("registerSpectrumResolution", w, " x ", h)
	table.insert(spectrumResolutions, {w=w, h=h})
end


function getSpectrumMeterList()
	return spectrumList
end

--function getSpectrumSettings()
--	local settings = {}
--	for _,v in ipairs(spectrumList) do
--		settings[v.name]={enabled=v.enabled, spType=v.spType, barColor=v.barColor, capColor=v.capColor}
--	end
--	return settings
--end

-- Workaround for mono-colour spectrums
-- if not present in settings add them
-- if present in settings then use those settings
local function initColourSpectrums()
	local csp ={
		{name="mc-White", enabled=false, spType=SPT_COLOUR,		barColor=0xd0d0d0ff, capColor=0xffffffff},
		{name="mc-White translucent", enabled=false, spType=SPT_COLOUR,	barColor=0xd0d0d0a0, capColor=0xd0d0d0ff},
		{name="mc-Yellow", enabled=false, spType=SPT_COLOUR,	   barColor=0xd0d000ff, capColor=0xffff00ff},
		{name="mc-Yellow translucent", enabled=false, spType=SPT_COLOUR,   barColor=0xd0d000a0, capColor=0xd0d000ff},
		{name="mc-Cyan", enabled=false, spType=SPT_COLOUR,		 barColor=0x00d0d0ff, capColor=0x00ffffff},
		{name="mc-Cyan translucent", enabled=false, spType=SPT_COLOUR,	 barColor=0x00d0d0a0, capColor=0x00d0d0ff},
		{name="mc-Magenta", enabled=false, spType=SPT_COLOUR,	  barColor=0xd000d0ff, capColor=0xff00ffff},
		{name="mc-Magenta translucent", enabled=false, spType=SPT_COLOUR,  barColor=0xd000d0a0, capColor=0xd000d0ff},
		{name="mc-Black", enabled=false, spType=SPT_COLOUR,		barColor=0x101010ff, capColor=0x000000ff},
		{name="mc-Black translucent", enabled=false, spType=SPT_COLOUR,	barColor=0x000000a0, capColor=0x000000ff},
		{name="mc-Green", enabled=false, spType=SPT_COLOUR,		barColor=0x00d000ff, capColor=0x00d000ff},
		{name="mc-Green translucent", enabled=false, spType=SPT_COLOUR,	barColor=0x00d000a0, capColor=0x00ff00ff},
		{name="mc-Blue", enabled=false, spType=SPT_COLOUR,		 barColor=0x0000d0ff, capColor=0x0000ffff},
		{name="mc-Blue translucent", enabled=false, spType=SPT_COLOUR,	 barColor=0x0000d0a0, capColor=0x0000ffff},
		{name="mc-Red", enabled=false, spType=SPT_COLOUR,		  barColor=0xd00000ff, capColor=0xff0000ff},
		{name="mc-Red translucent", enabled=false, spType=SPT_COLOUR,	  barColor=0xd00000a0, capColor=0xff0000ff},
	}
	for _,c in pairs(csp) do
		table.insert(spectrumList, c)
	end
end


local function __addSpectrumBacklit(path, entry)
		local mode = lfs.attributes(path .. "/" .. entry, "mode")
		if mode == "file" then
			local parts = _parseImagePath(entry)
			if parts ~= nil then
				local imgName = 'bl-' .. parts[1]
				local bgImgName = "bg-" .. imgName
				if spectrumImagesMap[imgName] == nil then
					table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_BACKLIT})
				end
				log:debug(" SpectrumImage :", imgName, " ", bgImgName, ", ", path .. "/" .. entry)
				spectrumImagesMap[imgName] = {fg=imgName, bg=bgImgName, src=path .. "/" .. entry}
			end
		end
end

--FIXME make idempotent
local function _populateSpectrumBacklitList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			__addSpectrumBacklit(search_root, entry)
		end
		if mode == "directory" then
			local path = search_root .. "/" .. entry
			for f in lfs.dir(path) do
				mode = lfs.attributes(path .. "/" .. f, "mode")
				if mode == "file" then
					__addSpectrumBacklit(path, f)
				end
			end
		end
	end
end

local function _scanSpectrumBacklitList(rpath)
	for search_root in findPaths(rpath) do
		_populateSpectrumBacklitList(search_root)
	end
end

local function __addSpectrumImage(path, entry)
	local mode = lfs.attributes(path .. "/" .. entry, "mode")
	if mode == "file" then
		local parts = _parseImagePath(entry)
		if parts ~= nil then
			local imgName = 'im-' .. parts[1]
			if spectrumImagesMap[imgName] == nil then
				table.insert(spectrumList, {name=imgName, enabled=false, spType=SPT_IMAGE})
			end
			log:debug(" SpectrumImage :", imgName, ", ", path .. "/" .. entry)
			spectrumImagesMap[imgName] = {fg=imgName, bg=nil, src=path .. "/" .. entry}
		end
	end
end

--FIXME make idempotent
local function _populateSpectrumImageList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
		if mode == "file" then
			__addSpectrumImage(search_root, entry)
		end
		if mode == "directory" then
			local path = search_root .. "/" .. entry
			for f in lfs.dir(path) do
				mode = lfs.attributes(path .. "/" .. f, "mode")
				if mode == "file" then
					__addSpectrumImage(path, f)
				end
			end
		end
	end
end

local function _scanSpectrumImageList(rpath)
	for search_root in findPaths(rpath) do
		_populateSpectrumImageList(search_root)
	end
end

local function initSpectrumList()
	spectrumList = {}
	spectrumImagesMap = {}

	initColourSpectrums()

	local relativePath = "assets/visualisers/spectrum/backlit"
	_scanSpectrumBacklitList("../../" .. relativePath)
	_scanSpectrumBacklitList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateSpectrumBacklitList(workSpace .. "/" .. relativePath)
	end

	relativePath = "assets/visualisers/spectrum/gradient"
	_scanSpectrumImageList("../../" .. relativePath)
	_scanSpectrumImageList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateSpectrumImageList(workSpace .. "/" .. relativePath)
	end
	table.sort(spectrumList, function (left, right) return left.name < right.name end)
end

local function enableOneSpectrumMeter()
		local enabled_count = 0
		-- try to select a meter which does not require a resize
		-- 1: try white colour
		for _, v in pairs(spectrumList) do
			if v.name == "mc-White" and v.spType == "colour" then
				v.enabled = true
				enabled_count = 1
			end
		end
		if enabled_count == 0 then
			-- 2: try a colour
			for _, v in pairs(spectrumList) do
				if v.spType == "colour" then
					v.enabled = true
					enabled_count = 1
					break
				end
			end
		end
		if enabled_count == 0 then
			-- 3: finally just use whatever is first in the list
			-- a resize may be involved at a later stage
			spectrumList[1].enabled = true
		end
end

local function populateSpSeq()
	local indx = 1
	spSeq = {}
	for i = 1, #spectrumList do
		if spectrumList[i].enabled == true then
		 spSeq[indx] = i
			indx = indx + 1
		end
	end
	if #spSeq == 0 then
		enableOneSpectrumMeter()
		populateSpSeq()
	end
end

local spSeqIndex = 1
local function __spBump(_, _)
	if #spSeq == 0 then
		populateSpSeq()
		ShuffleInPlace(spSeq)
		spSeqIndex = #spSeq +1
	end

	if spSeqIndex > #spSeq then
		spSeqIndex = 1
		populateSpSeq()
		ShuffleInPlace(spSeq)
	end
	spImageIndex = spSeq[spSeqIndex]
	if #spSeq == 0 then
		log:error("No spectrum meters enabled")
	end
	spSeqIndex = spSeqIndex + 1
	return true
end

function spChange(_, name)
	if name == "visuChangeOnTrackChange" and visSettings.visuChangeOnTrackChange then
		__spBump()
	end
	if name == "visuChangeOnNpViewChange" and visSettings.visuChangeOnNpViewChange then
		__spBump()
	end
	if name == "force" then
		__spBump()
	end
end

--local function spFindSpectrumByType(spType)
--	for i = 1, #spectrumList do
--		if spType == nil or spectrumList[i].spType == spType then
--			log:debug("spFindSpectrumByType is ", i, " of ", #spectrumList, ", ", spectrumList[i].name)
--			return spectrumList[i].name
--		end
--	end
--	-- type is not available - return type
--	return spectrumList[1].name
--end

local function _getFgSpectrumImage(spkey, w, h, _)
	local fgImage
	if spectrumImagesMap[spkey] == nil then
		return nil, false
	end
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg)
	if spectrumImagesMap[spkey].fg == nil then
		return nil, false
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].fg
	log:debug("getFgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].fg,
				" ", dicKey, " ", resizedImagesTable[dicKey])
	fgImage = loadResizedImage(dicKey)
	return fgImage, fgImage == nil
end

local function _getBgSpectrumImage(spkey, w, h, spType)
	local bgImage
	if spectrumImagesMap[spkey] == nil then
		return nil, false
	end
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg)
	if spectrumImagesMap[spkey].bg == nil then
		return nil, false
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].bg
	log:debug("getBgImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].bg, " ", dicKey)

	local resizeRequired = false
	bgImage = imCacheGet(dicKey)
	if bgImage == nil then
		local fgimg, fgResizeRequired = _getFgSpectrumImage(spkey, w, h, spType)
		resizeRequired = fgResizeRequired
		if fgimg ~= nil then
			-- FIXME:
			-- Odd: it appears that when invoking blitAlpha from the foreground image to the background image,
			-- the foreground image is affected by the alpha value.
			-- For now work around by isolating, blit foreground to a temporary image and then blitAlpha
			-- from the temporary image to the background image
			local tmp = Surface:newRGB(w,h)
			tmp:filledRectangle(0,0,w,h,0)
			fgimg:blit(tmp, 0, 0)
			bgImage = Surface:newRGB(w,h)
			tmp:blitAlpha(bgImage, 0, 0, visSettings.spectrum.backlitAlpha)
			tmp:altRelease()
			imCachePut(dicKey, bgImage)
		end
	end
	return bgImage, resizeRequired
end

local prevSpImageIndex = -1
function getSpectrum(_, w, h, barColorIn, capColorIn)
	log:debug("getSpectrum: ", w, " ", h)
	local spkey = spectrumList[spImageIndex].name
--	if not spectrumList[spImageIndex].enabled or (spType ~= nil and spectrumList[spImageIndex].spType ~= spType) then
--		if not __spBump(nil, spType) then
--			spkey = spFindSpectrumByType(spType)
--		else
--			spkey = spectrumList[spImageIndex].name
--		end
--		__spBump(nil, nil)
--	end
	log:debug("getSpectrum: spkey: ", spkey)
	local alpha = visSettings.spectrum.backlitAlpha

	if visSettings.cacheEnabled == false and prevSpImageIndex ~= spImageIndex then
		imCacheClear()
	end
	prevSpImageIndex = spImageIndex

	local fg, fgResizeRequired = _getFgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	local bg, bgResizeRequired = _getBgSpectrumImage(spkey, w, h, spectrumList[spImageIndex].spType)
	local barColor = spectrumList[spImageIndex].barColor and spectrumList[spImageIndex].barColor or barColorIn
	local capColor = spectrumList[spImageIndex].capColor and spectrumList[spImageIndex].capColor or capColorIn
	local displayResizing = makeResizingParams(fgResizeRequired or bgResizeRequired)

	return fg, bg, alpha, barColor, capColor, displayResizing
end

function selectSpectrum(_, name, selected)
	local n_enabled = 0
	log:debug("selectSpectrum", " ", name, " ", selected)

	for _, v in pairs(spectrumList) do
		if v.name == name then
			if not selected and v.enabled then
				v.enabled = selected
				-- deselected so re-sequence
				spSeq = {}
				__spBump()
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectSpectrum", " enabled count: ", n_enabled)
--	spSeq = {}
--	__spBump()
	return n_enabled
end

function isCurrentSpectrumEnabled()
	return spectrumList[spImageIndex].enabled
end

--------------------------------------------------------
--- Spectrum bars format
--------------------------------------------------------
--function getBarsFormat()
--	log:debug("getBarsFormat", " ", visSettings.spectrum.barsFormat)
--	return visSettings.spectrum.barFormats[visSettings.spectrum.barsFormat]
--end
--
--------------------------------------------------------
--- Spectrum caps
--------------------------------------------------------
--function getCapsValues(_, capsHeight, capsSpace)
--	if not visSettings.spectrum.capsOn then
--		return {0,0}, {0,0}
--	end
--	return capsHeight, capsSpace
--end
--
--------------------------------------------------------
--- Spectrum baseline
--------------------------------------------------------
--function getBaselineValues(_)
--	return visSettings.spectrum.baselineAlways, visSettings.spectrum.baselineOn
--end
--
--
--------------------------------------------------------
--- Spectrum turbine
--------------------------------------------------------
--function getSpectrumTurbine(_)
--	log:debug("getSpectrumTurbine", " ", visSettings.spectrum.turbine)
--	return visSettings.spectrum.turbine
--end

---------------------------------------------------------
--- Spectrum channel flip
--------------------------------------------------------
local channelFlips  = {
		LHHL={0,1},
		HLHL={1,1},
		HLLH={1,0},
		LHLH={0,0},
}

--function getChannelFlipValues()
--	log:debug("getChannelFlipValues", " ", visSettings.spectrum.channelFlip,
--				" ", channelFlips[visSettings.spectrum.channelFlip])
--	return channelFlips[visSettings.spectrum.channelFlip]
--end

function getSpectrumMeterSettings(_, capHeightIn, capSpaceIn)
	local capHeight = capHeightIn
	local capSpace = capSpaceIn
	if not visSettings.spectrum.capsOn then
		capHeight = {0,0}
		capSpace = {0,0}
	end
	return {
		channelFlipped=channelFlips[visSettings.spectrum.channelFlip],
		barsFormat=visSettings.spectrum.barFormats[visSettings.spectrum.barsFormat],
		capHeight=(capHeight[1]+capHeight[2])/2,
		capSpace=(capSpace[1]+capSpace[2])/2,
		turbine=visSettings.spectrum.turbine,
		baselineAlways=visSettings.spectrum.baselineAlways,
		baselineOn=visSettings.spectrum.baselineOn,
	}
end
--------------------------------------------------------
--- VU meter
--------------------------------------------------------
local vuImageIndex = 1
local vuImagesMap = {}
local vuMeterResolutions = {}
local vfdImageSources = {}

function registerVUMeterResolution(_, w,h)
	log:debug("registerVUMeterResolution ", w, " x ", h)
	table.insert(vuMeterResolutions, {w=w, h=h})
end

function getVuMeterList()
	return vuImages
end

local function _populateVfdVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				local path = search_root .. "/" .. entry
				for f in lfs.dir(path) do
					mode = lfs.attributes(path .. "/" .. f, "mode")
					if mode == "file" then
						local parts = _parseImagePath(f)
						if parts ~= nil then
							log:debug("VFD ", entry .. ":" .. parts[1], "  ", path .. "/" .. f)
							vfdImageSources[entry .. ":" .. parts[1]] = path .. "/" .. f
						end
					end
				end
				table.insert(vuImages, {name=entry, enabled=false, displayName='vfd-' .. entry, vutype="vfd"})
			end
		end
	end
end

local function _initVfdVuMeterList(rpath)
	for search_root in findPaths(rpath) do
		_populateVfdVuMeterList(search_root)
	end
end

--local function _populateAnalogueVuMeterList(search_root)
--	if (lfs.attributes(search_root, "mode") ~= "directory") then
--		return
--	end
--
--	for entry in lfs.dir(search_root) do
--		local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
--		if mode == "file" then
--			local parts = _parseImagePath(entry)
--			if parts ~= nil then
--				local imgName = parts[1]
--				local displayName = imgName
--				local ixSub = string.find(imgName, "25seq")
--				if ixSub ~= nil then
--					if string.find(imgName, "25seq_") ~= nil or string.find(imgName, "25seq-") ~= nil then
--						displayName = '25f-' .. string.sub(imgName, ixSub + 6)
--					else
--						displayName = '25f-' .. string.sub(imgName, ixSub + 5)
--					end
--				end
--				log:debug("Analogue VU meter :", imgName, " ", displayName, ", ", search_root .. "/" .. entry)
--				table.insert(vuImages, {name=imgName, enabled=false, displayName=displayName, vutype="frame"})
--				vuImagesMap[imgName] = {src=search_root .. "/" .. entry}
--			end
--		end
--	end
--end
--
--local function _initAnalogueVuMeterList(rpath)
--	for search_root in findPaths(rpath) do
--		_populateAnalogueVuMeterList(search_root)
--	end
--end

local function _populate25fVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				local path = search_root .. "/" .. entry
				local found = 0
				for f in lfs.dir(path) do
					mode = lfs.attributes(path .. "/" .. f, "mode")
					if mode == "file" then
						local parts = _parseImagePath(f)
						if parts ~= nil then
							log:debug("25frames ", path .. "/" .. f)
							vuImagesMap[entry] = {src= path .. "/" .. f}
							found = found + 1
						end
					end
				end
				if found == 1 then
					log:debug("25frames ", entry)
					table.insert(vuImages, {name=entry, enabled=false, displayName='25f-' .. entry, vutype="frame"})
				end
			end
		end
	end
end

local function _init25fVuMeterList(rpath)
	for search_root in findPaths(rpath) do
		_populate25fVuMeterList(search_root)
	end
end


local function _populate25fLRVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				local path = search_root .. "/" .. entry
				local found = 0
				for f in lfs.dir(path) do
					mode = lfs.attributes(path .. "/" .. f, "mode")
					if mode == "file" then
						local parts = _parseImagePath(f)
						if parts ~= nil then
							log:debug("25framesLR ", path .. "/" .. f)
							if string.find(parts[#parts-1], 'left') ~= nil then
								vuImagesMap[entry .. ':left'] = {src= path .. "/" .. f}
								found = found + 1
							end
							if string.find(parts[#parts-1], 'right') ~= nil then
								vuImagesMap[entry .. ':right'] = {src= path .. "/" .. f}
								found = found + 1
							end
						end
					end
				end
				if found == 2 then
					log:debug("25framesLR ", entry)
					table.insert(vuImages, {name=entry, enabled=false, displayName='25flr-' .. entry, vutype="25framesLR"})
				end
			end
		end
	end
end

local function _init25fLRVuMeterList(rpath)
	for search_root in findPaths(rpath) do
		_populate25fLRVuMeterList(search_root)
	end
end


local function initVuMeterList()
	vuImages = {}
	vuImagesMap = {}

	local relativePath = "assets/visualisers/vumeters/vfd"
	_initVfdVuMeterList("../../" .. relativePath)
	_initVfdVuMeterList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populateVfdVuMeterList(workSpace .. "/" .. relativePath)
	end
--	relativePath = "assets/visualisers/vumeters/analogue"
--	_initAnalogueVuMeterList("../../" .. relativePath)
--	_initAnalogueVuMeterList(relativePath)
--	if workSpace ~= System.getUserDir() then
--		_populateAnalogueVuMeterList(workSpace .. "/" .. relativePath)
--	end
	relativePath = "assets/visualisers/vumeters/25frames"
	_init25fVuMeterList("../../" .. relativePath)
	_init25fVuMeterList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populate25fVuMeterList(workSpace .. "/" .. relativePath)
	end
	relativePath = "assets/visualisers/vumeters/25framesLR"
	_init25fLRVuMeterList("../../" .. relativePath)
	_init25fLRVuMeterList(relativePath)
	if workSpace ~= System.getUserDir() then
		_populate25fLRVuMeterList(workSpace .. "/" .. relativePath)
	end
	table.sort(vuImages, function (left, right) return left.displayName < right.displayName end)
end

-- Enable at least one valid VU Meter
local function enableOneVUMeter()
		local enabled_count = 0
		-- select a default try to find a vfd (no resize required)
		-- 1: try "RS-M250"
		for _, v in pairs(vuImages) do
			if v.name == "RS-M250" and v.vutype=="vfd" then
				v.enabled = true
				enabled_count = 1
			end
		end
		if enabled_count == 0 then
			-- 2: try any VFD
			for _, v in pairs(vuImages) do
				if v.vutype=="vfd" then
					v.enabled = true
					enabled_count = 1
					break
				end
			end
		end
		if enabled_count == 0 then
			-- 3: finally just use whatever is first in the list
			-- a resize may be involved at a later stage
			vuImages[1].enabled = true
		end
end

local function populateVuSeq()
	local indx = 1
	vuSeq = {}
	for i = 1, #vuImages do
		if vuImages[i].enabled == true then
			vuSeq[indx] = i
			indx = indx + 1
		end
	end
	if #vuSeq == 0 then
		enableOneVUMeter()
		populateVuSeq()
	end
end

local vuSeqIndex = 1
local function __vuBump()
	if #vuSeq == 0 then
		populateVuSeq()
		ShuffleInPlace(vuSeq)
		vuSeqIndex = #vuSeq +1
	end
	if vuSeqIndex > #vuSeq then
		vuSeqIndex = 1
		populateVuSeq()
		ShuffleInPlace(vuSeq)
	end
	vuImageIndex = vuSeq[vuSeqIndex]
	if #vuSeq == 0 then
		log:error("No VU meters enabled")
	end
	vuSeqIndex = vuSeqIndex + 1
end

function vuChange(_, name)
	if name == "visuChangeOnTrackChange" and visSettings.visuChangeOnTrackChange then
		__vuBump()
	end
	if name == "visuChangeOnNpViewChange" and visSettings.visuChangeOnNpViewChange then
		__vuBump()
	end
	if name == "force" then
		__vuBump()
	end
end

local function _resizedVFDElement(srcImg, key, w, h)
	local dicKey = key .. "-" .. w .. "x" .. h
	log:info("_resizedVFDElement ", "key=", key, " dicKey=", dicKey)
	local img = loadResizedImage(dicKey)
	if img == nil then
		img = srcImg:resize(w, h)
		local dcpath = resizedImagePath(dicKey)
		saveImage(img, dicKey, dcpath)
--		resizedImagesTable[dicKey] = dcpath
		imCachePut(dcpath, img)
		srcImg:altRelease()
	end
	return img
end

-- FIXME: vfdCache should go through imCache
local function getVFDVUmeter(name, w, h)
	local key = name .. w .. "x" .. h
	local vfd = vfdCache[key]
	if vfd ~= nil then
		log:info("vfdCache -> ", key, vfd)
		return vfd
	end
	local bar_on = name .. ":bar-on"
	local bar_off = name .. ":bar-off"
	local bar_peak_on = name .. ":bar-peak-on"
	local bar_peak_off = name .. ":bar-peak-off"

	local r_bar_on = name .. ":r-bar-on"
	local r_bar_off = name .. ":r-bar-off"
	local r_bar_peak_on = name .. ":r-bar-peak-on"
	local r_bar_peak_off = name .. ":r-bar-peak-off"

	if vfdImageSources[r_bar_on] == nil then
		r_bar_on = bar_on
	end
	if vfdImageSources[r_bar_off] == nil then
		r_bar_off = bar_off
	end
	if vfdImageSources[r_bar_peak_on] == nil then
		r_bar_peak_on = bar_peak_on
	end
	if vfdImageSources[r_bar_peak_off] == nil then
		r_bar_peak_off = bar_peak_off
	end

	local left = name .. ":left"
	local right = name .. ":right"
	local left_trail = name .. ":left-trail"
	local right_trail = name .. ":right-trail"
	local center = name .. ":center"
	vfd = {}
	vfd.left={}
	vfd.right={}
	-- bar render x-offset
	vfd.left.on = loadImage(vfdImageSources[bar_on])
	vfd.left.off = loadImage(vfdImageSources[bar_off])
	vfd.left.peakon = loadImage(vfdImageSources[bar_peak_on])
	vfd.left.peakoff = loadImage(vfdImageSources[bar_peak_off])

	vfd.right.on = loadImage(vfdImageSources[r_bar_on])
	vfd.right.off = loadImage(vfdImageSources[r_bar_off])
	vfd.right.peakon = loadImage(vfdImageSources[r_bar_peak_on])
	vfd.right.peakoff = loadImage(vfdImageSources[r_bar_peak_off])

	vfd.leftlead = loadImage(vfdImageSources[left])
	vfd.rightlead = loadImage(vfdImageSources[right])
	vfd.lefttrail = loadImage(vfdImageSources[left_trail])
	vfd.righttrail = loadImage(vfdImageSources[right_trail])
	vfd.center = loadImage(vfdImageSources[center])

	local bw, bh = vfd.left.on:getSize()
	local lw, lh = vfd.leftlead:getSize()
	local tw, th = 0, 0
	if vfd.lefttrail ~= nil then
		tw, th = vfd.lefttrail:getSize()
	end

	local cw, ch = vfd.center:getSize()
	local dw = cw
	local dh = ch + (bh * 2)
	local barwidth = math.floor((cw - lw)/49)
	local calcbw = (cw - lw - tw)/49
--	log:debug("#### bw:", bw, " barwidth:", barwidth)
	-- vfd.bar_rxo= barwidth - bw
	vfd.left.bar_rxo= 0
	vfd.right.bar_rxo= 0
--	log:debug("#### dw:", dw, " dh:", dh, " w:", w, " h:", h)
--	log:debug("#### ",lw, ",", lh, "  ", bw, ",", bh, "  ", cw, "," , ch)
	if w > dw and h >= dh then
		vfd.w = dw
		vfd.h = dh
	else
		local sf = math.min(w/dw, h/dh)
--		log:debug("#### vfd : sf : ", sf)
		barwidth = math.floor(barwidth * sf)
		calcbw = math.floor(calcbw * sf)
		bw = math.floor(bw * sf)
		bh = math.floor(bh * sf)
		lw = math.floor(lw * sf)
		lh = math.floor(lh * sf)
		tw = math.floor(tw * sf)
		-- Due to rounding errors, scaling the calibration part like so
		-- cw = math.floor((cw * sf))
		-- scales at odds with the smaller bits.
--	  	log:debug("delta calc vs sf ", (calcbw *49) + lw + tw - cw)
		cw = (calcbw *49) + lw + tw
		ch = math.floor((ch * sf))
		-- vfd.bar_rxo= barwidth - bw
		vfd.left.on = _resizedVFDElement(vfd.left.on, bar_on, bw, bh)
		vfd.left.off = _resizedVFDElement(vfd.left.off, bar_off, bw, bh)
		vfd.left.peakon = _resizedVFDElement(vfd.left.peakon, bar_peak_on, bw, bh)
		vfd.left.peakoff = _resizedVFDElement(vfd.left.peakoff, bar_peak_off, bw, bh)
		vfd.right.on = _resizedVFDElement(vfd.right.on, r_bar_on, bw, bh)
		vfd.right.off = _resizedVFDElement(vfd.right.off, r_bar_off, bw, bh)
		vfd.right.peakon = _resizedVFDElement(vfd.right.peakon, r_bar_peak_on, bw, bh)
		vfd.right.peakoff = _resizedVFDElement(vfd.right.peakoff, r_bar_peak_off, bw, bh)

		vfd.leftlead = _resizedVFDElement(vfd.leftlead, left, lw, lh)
		vfd.rightlead = _resizedVFDElement(vfd.rightlead, right, lw, lh)
		vfd.center = _resizedVFDElement(vfd.center, center, cw, ch)
		vfd.w = cw
		vfd.h = ch + (bh * 2)
	end
	vfd.left.barwidth = barwidth
	vfd.right.barwidth = barwidth
	vfd.bw = bw
	vfd.bh = bh
	vfd.lw = lw
	vfd.lh = lh
	vfd.cw = cw
	vfd.ch = ch
--	log:debug("####  vfd.w:", vfd.w, " vfd.h:", vfd.h)
--	log:debug("####  vfd.bw:", vfd.bw, " vfd.bh:", vfd.bh, " vfd.lw:", vfd.lw, " vfd.lh", vfd.lh)
--	log:debug("####  vfd.cw:", vfd.cw, " vfd.ch", vfd.ch)
	log:info("vfdCache <- ", key, vfd)
	vfdCache[key] = vfd
	return vfd
end


local prevVuImageIndex = -1
function getVuImage(_,w,h)
	log:debug("getVuImage ", vuImageIndex, ", ", vuImages[vuImageIndex])
--	if vuImages[vuImageIndex].enabled == false then
--		__vuBump()
--	end
	local entry = vuImages[vuImageIndex]

	if visSettings.cacheEnabled == false and vuImageIndex ~= prevVuImageIndex then
		imCacheClear()
	end
	prevVuImageIndex = vuImageIndex

	if entry.vutype == "vfd" then
		return  {vutype=entry.vutype, vfd=getVFDVUmeter(entry.name, w, h)}
	end

	local frameVU

	if entry.vutype == "25framesLR" then
		local ldicKey = "for-" .. w .. "x" .. h .. "-" .. entry.name .. ':left'
		local rdicKey =  "for-" .. w .. "x" .. h .. "-" .. entry.name .. ':right'
		local leftImg = loadResizedImage(ldicKey)
		local rightImg = loadResizedImage(rdicKey)
		return {vutype=entry.vutype, leftImg=leftImg, rightImg=rightImg, displayResizing=makeResizingParams(leftImg==nil or  rightImg==nil)}
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" .. entry.name
	-- image is in the cache load and return
	log:debug("getVuImage: load ", dicKey, " ", resizedImagesTable[dicKey])
	frameVU = loadResizedImage(dicKey)
	return {vutype=entry.vutype, bgImg=frameVU, displayResizing=makeResizingParams(frameVU==nil)}
end


function selectVuImage(_, name, selected)
	local n_enabled = 0
	log:debug("selectVuImage", " ", name, " ", selected)
	for _, v in pairs(vuImages) do
		if v.name == name then
			if not selected and v.enabled then
				v.enabled = selected
				-- deselected so re-sequence in
				vuSeq = {}
				__vuBump()
			end
			v.enabled = selected
		end
		if v.enabled then
			n_enabled = n_enabled + 1
		end
	end
	log:debug("selectVuImage", " enabled count: ", n_enabled)
	return n_enabled
end

function isCurrentVUMeterEnabled()
	return vuImages[vuImageIndex].enabled
end


-------------------------------------------------------
--- Misc
--------------------------------------------------------

--function sync()
--	if not vuImages[vuImageIndex].enabled then
--		__vuBump()
--	end
--	if not spectrumList[spImageIndex].enabled then
--		__spBump(nil,nil)
--	end
--end

-------------------------------------------------------
--- Resize
-------------------------------------------------------
function enumerateResizableSpectrumMeters(_, all)
    local spMeters = {}
	for _, v in pairs(spectrumList) do
		if (v.spType == SPT_BACKLIT or v.spType == SPT_IMAGE) and (all or v.enabled) then
			for _, vr in pairs(spectrumResolutions) do
				if spectrumImagesMap[v.name].src ~= nil then
					table.insert(spMeters, {name=v.name, w=vr.w, h=vr.h})
				end
			end
		end
	end
    return spMeters
end

function concurrentResizeSpectrumMeter(_, name, w, h)
--	log:info("concurrentResizeSpectrumMeter ", name, ", ", w, ", ", h)
	for _, v in pairs(spectrumList) do
		if name == v.name then
			-- create the resized images for skin resolutions
			if spectrumImagesMap[v.name].src ~= nil then
				local path = spectrumImagesMap[v.name].src
				local dicKey = "for-" .. w .. "x" .. h .. "-" .. name
				local dcpath = resizedImagePath(dicKey)
                if resizedImagesTable[dicKey] ~= nil then
                    return true
                end
				local ok
				if v.spType == SPT_BACKLIT then
					ok = Surface:requestResize(path, dcpath, w, h, 0, 3, saveimage_type) == 1
                elseif v.spType == SPT_IMAGE then
					ok = Surface:requestResize(path, dcpath, w, h, 0, 2, saveimage_type) == 1
                else
                    ok = true
				end
				if ok then
					resizedImagesTable[dicKey] = dcpath
					return true
				end
			end
		end
	end
	return false
end

function enumerateResizableVuMeters(_, all)
    local vMeters = {}
	for _, v in pairs(vuImages) do
		if all or v.enabled then
			if v.vutype == "frame" then
				for _, vr in pairs(vuMeterResolutions) do
					table.insert(vMeters, {name=v.name, w=vr.w, h=vr.h})
				end
			end
			if v.vutype == "25framesLR" then
				for _, vr in pairs(vuMeterResolutions) do
					table.insert(vMeters, {name=v.name, w=vr.w, h=vr.h})
				end
			end
		end
	end
    return vMeters
end

local function requestVuResize(name, w , h)
--	log:info("requestVuResize ", name, ", ", w, ", ", h)
	local path = vuImagesMap[name].src
	local dicKey = "for-" .. w .. "x" .. h .. "-" .. name
	local dcpath = resizedImagePath(dicKey)
	if resizedImagesTable[dicKey] ~= nil then
		return true
	end
	local ok = Surface:requestResize(path, dcpath, w, h, 25, 1, saveimage_type) == 1
	if ok then
		resizedImagesTable[dicKey] = dcpath
		return true
	end
	return false
end

function concurrentResizeVuMeter(_, name, w, h)
--	log:info("concurrentResizeVuMeter ", name, ", ", w, ", ", h)
	for _, v in pairs(vuImages) do
		if name == v.name then
			if v.vutype == "frame" then
				return requestVuResize(name, w, h)
			end

			if v.vutype == "25framesLR" then
				local l =  requestVuResize(name .. ':left', w, h)
				local r =  requestVuResize(name .. ':right', w, h)
				return l and r
			end
		end
	end
	return false
end

function getCurrentVuMeterName()
	return vuImages[vuImageIndex].name
end

function getCurrentSpectrumMeterName()
	return spectrumList[spImageIndex].name
end

function resizeRequiredSpectrumMeter(_, name)
	for _, v in pairs(spectrumList) do
		if v.name == name then
			-- spectrum meter found
			if v.spType == SPT_BACKLIT or v.spType == SPT_IMAGE then
				-- of type that does require resize
				if spectrumImagesMap[name].src ~= nil then
					-- have path to source image
					for _, vr in pairs(spectrumResolutions) do
						if resizedImagesTable["for-" .. vr.w .. "x" .. vr.h .. "-" .. name] == nil then
							return true
						end
					end
				end
			end
			-- not resizable 1) not resizable type 2) no source image
			break
		end
	end
	-- spectrum meter not resizable : not found, not resizable, no source images
	return false
end

function resizeRequiredVuMeter(_, name)

	for _, v in pairs(vuImages) do
		if v.name == name then
			-- found vu meter
			if v.vutype == "frame" then
				-- resizable type
				for _, vr in pairs(vuMeterResolutions) do
					if resizedImagesTable["for-" .. vr.w .. "x" .. vr.h .. "-" .. name] == nil then
						return true
					end
				end
			end
			if v.vutype == "25framesLR" then
				-- create the cached image for skin resolutions
				for _, vr in pairs(vuMeterResolutions) do
					if resizedImagesTable["for-" .. vr.w .. "x" .. vr.h .. "-" .. name .. ':left'] == nil then
						return true
					end
					if resizedImagesTable["for-" .. vr.w .. "x" .. vr.h .. "-" .. name .. ':right'] == nil then
						return true
					end
				end
			end
			break
		end
	end
	-- vu meter not resizable : not found, not resizable
	return false
end

function getVisualiserChangeOnTimerValue(_)
	local value = visSettings.visuChangeOnTimer
	if value == nil then
		return 0
	end
	return value
end

function getWorkspacePath(_)
	return "" .. workSpace
end

function getDefaultWorkspacePath(_)
	return "" .. defaultWorkspace
end

--------------------------------------------------------
--- Initialisation and settings
--------------------------------------------------------
function setVisSettings(_, settings)
	visSettings = settings

	platformDetect()
	initialiseCache()

	-- try persistent load of resizing image
	for search_root in findPaths("../../assets/images") do
		for entry in lfs.dir(search_root) do
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "file" then
			 local parts = _parseImagePath(entry)
				if parts ~= nil and parts[1] == "animated_resizing" then
					local resizingImg = Surface:altLoadImage(search_root .. "/" .. entry )
					local w,h = resizingImg:getSize()
					displayResizingParameters = { img=resizingImg, w=w, h=h }
					log:info("found resizing image", resizingImg)
				end
			end
		end
	end

	initSpectrumList()
	local enabled_count = 0

	for k, v in pairs(settings.spectrumMeterSelection) do
		-- set flags but do not cache
		selectSpectrum(nil, k, v, false)
		if v then
			enabled_count = enabled_count + 1
		end
	end
	if enabled_count == 0 and #spectrumList > 0 then
		enableOneSpectrumMeter()
	end

	initVuMeterList()
	enabled_count = 0
	for k, v in pairs(settings.vuMeterSelection) do
		-- set flags but do not cache
		selectVuImage(nil, k, v , false)
		if v then
			enabled_count = enabled_count + 1
		end
	end
	if enabled_count == 0 and #vuImages > 0 then
		enableOneVUMeter()
	end
	__spBump()
	__vuBump()
end

function initialiseCache()
	imCacheClear()

	-- find and use artwork resized ahead of time offline
	for search_root in findPaths("../../assets/resized") do
		_populateResizedImagesTable(search_root)
	end
	-- find and use artwork resized ahead of time offline
	for search_root in findPaths("assets/resized") do
		_populateResizedImagesTable(search_root)
	end

	_populateResizedImagesTable(resizedCachePath)
end

function initialise()
end


