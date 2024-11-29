 --[[
 =head1 NAME

 jive.visImage - visualiser support

 =head1 DESCRIPTION

 Implements visualiser support
  - menu selection support
  - resize for multiple resoultions
  - image caching
  - ....

 (c) Blaise Dias, 2023-2024

 =cut
 --]]

--
-- lua package imports
local math	= require("math")
local table	= require("table")
local lfs	= require("lfs")
local os	= require("os")
local io	= require("io")

local ipairs, pairs = ipairs, pairs
local pcall = pcall
local coroutine, package	= coroutine, package

-- jive package imports
local string		= require("jive.utils.string")
local Surface		= require("jive.ui.Surface")
--local vis			= require("jive.vis")
--local debug		 	= require("jive.utils.debug")
local log			= require("jive.utils.log").logger("jivelite.vis")
local System		= require("jive.System")
local FRAME_RATE	= jive.ui.FRAME_RATE
local json			= require("jive.json")

module(...)

-- Spectrum visualisation types
--local SPT_DEFAULT = "default"
local SPT_BACKLIT = "backlit"
local SPT_IMAGE = "image"
local SPT_COLOUR = "colour"

-- values must match C code (jive_surface.c)
local RESIZEOP_VU					= 1
local RESIZEOP_FILL					= 2
local RESIZEOP_SCALED_CENTERED_CROP	= 3

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

local function pathsAreImageFiles(root_path, path_lst)
	for _, pth in ipairs(path_lst) do
		local src = root_path .. "/" .. pth
		local mode = lfs.attributes(src, "mode")
		if mode ~= "file" or _parseImagePath(src) == nil then
		 return false
end
	end
	return true
end

local function dumpTable(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		print(string.rep(" ", indent) .. tostring(k) .. ":")
		if type(v) == "table" then
			dumpTable(v, indent + 2)
		else
			print(string.rep(" ", indent + 2) .. tostring(v))
		end
	end
end

-- only insert non-nil values into table
local function tbl_insert(tbl, val)
	if val ~= nil then
		table.insert(tbl, val)
	end
end

local function loadJsonFile(jsPath)
	local jsonData = nil

	if (lfs.attributes(jsPath, "mode") ~= "file") then
		log:warn("loadJson: not a file ", jsPath, " ", lfs.attributes(jsPath, "mode"))
		return jsonData
	end

	local file = io.open(jsPath, "rb")
	if file ~= nil then
		local content = file:read "*a"
		file:close()
		local status, resOrError = pcall(json.parse, content)
		if status then
			jsonData = resOrError
		else
			log:error("json.parse ", jsPath, " error: ", resOrError)
		end
	else
		log:warn("loadJson: failed to open file ", jsPath)
	end
	return jsonData
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
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/spectrum")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters")
	os.execute("mkdir -p " .. workSpace .. "/assets/visualisers/vumeters")
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
	-- The resize queue is not cleared after a resize op is completed,
	-- this prevents repeating the same resize op if requested again.
	-- However now those images that were resized have been deleted,
	-- so the queue should be cleared.
	local cleared = Surface:clearResizeQueue()
	log:info("clearResizeQueue  returned: ", cleared)
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
local channelFlips  = {
		LHHL={0,1},
		HLHL={1,1},
		HLLH={1,0},
		LHLH={0,0},
}

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
		{
			name="mc-White",   enabled=false, spType=SPT_COLOUR,
			barColor=0xf0f0f0ff, capColor=0xffffffff, desatColor=0xc0c0c080
		},
		{
		 name="mc-Yellow",  enabled=false, spType=SPT_COLOUR,
			barColor=0xffff00ff, capColor=0xffff00ff, desatColor=0xd0d00080
		},
		{
			name="mc-Cyan",	enabled=false, spType=SPT_COLOUR,
			barColor=0x00ffffff, capColor=0x00ffffff, desatColor=0x00d0d080
		},
		{
			name="mc-Green",   enabled=false, spType=SPT_COLOUR,
--			barColor=0x00d000ff, capColor=0x00d000ff, desatColor=0x00d000a0
			barColor=0x00ff00ff, capColor=0x00ff00ff, desatColor=0x00d00080
		},
	}
	for _,c in pairs(csp) do
		table.insert(spectrumList, c)
	end
end

local function __addSpectrum(path, jsData)
	if spectrumImagesMap[jsData.name] ~= nil then
		return
	end

	-- check that all files referenced exist
	-- insert a nil value in a table stops iteration there
	local tmp = {}
	tbl_insert(tmp, jsData.foreground)
	tbl_insert(tmp, jsData.background)
	tbl_insert(tmp, jsData.desaturated)
	if jsData.turbine ~= nil then
		tbl_insert(tmp, jsData.turbine.foreground)
		tbl_insert(jsData.turbine.background)
		tbl_insert(tmp, jsData.turbine.desaturated)
	end
	if pathsAreImageFiles(path, tmp) == false then
		return false
	end

	local imgName = jsData.name
	local propN = {
		fg=imgName,
		ds="ds-" .. imgName,
		bg="bg-" .. imgName,
	}
	propN["src_fg"] =  path .. "/" .. jsData.foreground
	if jsData.desaturated ~= nil then
		propN["src_ds"] = path .. "/" .. jsData.desaturated
	end
	if jsData.background ~= nil then
		propN["src_bg"] = path .. "/" .. jsData.background
	end

	table.insert(spectrumList, {name=imgName, enabled=false, spType=jsData.sptype})

	local rszOp = RESIZEOP_FILL
	if jsData.sptype == SPT_BACKLIT then
		rszOp = RESIZEOP_SCALED_CENTERED_CROP
	else
		propN["bg"] = nil
	end
	local propT = nil
	if jsData.turbine ~= nil then
		if jsData.turbine.foreground ~= nil then
			propT = {
				fg="trb-" .. imgName,
				ds="trb-ds-" .. imgName,
				bg="trb-bg-" .. imgName,
			}
			propT["src_fg"] =  path .. "/" .. jsData.turbine.foreground
			if jsData.turbine.desaturated ~= nil then
				propT["src_ds"] =  path .. "/" .. jsData.turbine.desaturated
			end
			if jsData.turbine.background ~= nil then
				propT["src_bg"] =  path .. "/" .. jsData.turbine.background
			end
			if jsData.sptype ~= SPT_BACKLIT then
				propT["bg"] =  nil
			end
		end
	end
	spectrumImagesMap[imgName] = {
		properties = {
			propN,
			propT,
		},
		rszOp = rszOp,
	}
	log:info("SpectrumImage :", imgName)
end


--FIXME make idempotent
local function _populateSpectrum(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				local path = search_root .. "/" .. entry
				local jsData = loadJsonFile(path .. "/" .. "meta.json")
				if jsData ~= nil then
					if jsData.kind == "spectrum-meter" then
						__addSpectrum(path, jsData)
					end
				end
			end
		end
	end
end

local function _scanSpectrum(rpath)
	for search_root in findPaths(rpath) do
		_populateSpectrum(search_root)
	end
end

local function initSpectrumList()
	spectrumList = {}
	spectrumImagesMap = {}

	initColourSpectrums()

	local relativePath = "assets/visualisers/spectrum"
	if workSpace ~= System.getUserDir() then
		_populateSpectrum(workSpace .. "/" .. relativePath)
	end
	_scanSpectrum(relativePath)
	_scanSpectrum("../../" .. relativePath)
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

local function _getFgSpectrumImage(spkey, w, h, propsIndex)
	local fgImage
	if spectrumImagesMap[spkey] == nil then
		return nil, false, nil
	end
	log:debug("getFgSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].fg)
	if spectrumImagesMap[spkey].properties[propsIndex].fg == nil then
		return nil, false, nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].properties[propsIndex].fg
	log:debug("getFgSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].fg,
				" ", dicKey, " ", resizedImagesTable[dicKey])
	fgImage = loadResizedImage(dicKey)
	return fgImage, fgImage == nil, {key=dicKey, src=spectrumImagesMap[spkey].properties[propsIndex].src_fg}
end

local function _getBgSpectrumImage(spkey, w, h, fgimg, propsIndex)
	local bgImage
	if spectrumImagesMap[spkey] == nil then
		return nil, false, nil
	end
	log:debug("getBgSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].bg)
	if spectrumImagesMap[spkey].properties[propsIndex].bg == nil then
		return nil, false, nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].properties[propsIndex].bg
	log:debug("getBgSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].bg, " ", dicKey)

	if spectrumImagesMap[spkey].properties[propsIndex].src_bg ~= nil then
		bgImage = loadResizedImage(dicKey)
		return bgImage, bgImage == nil, {key=dicKey, src=spectrumImagesMap[spkey].properties[propsIndex].src_bg}
	end

	local resizeRequired = false
	bgImage = imCacheGet(dicKey)
	if bgImage == nil then
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
	return bgImage, resizeRequired, nil
end


local function _getDsSpectrumImage(spkey, w, h, fgimg, propsIndex)
	local dsImage
	if spectrumImagesMap[spkey] == nil then
		return nil, false, nil
	end
	log:debug("getDsSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].ds)
	if spectrumImagesMap[spkey].properties[propsIndex].ds == nil then
		return nil, false, nil
	end

	local dicKey = "for-" .. w .. "x" .. h .. "-" ..  spectrumImagesMap[spkey].properties[propsIndex].ds
	log:debug("getDsSpectrumImage: ", spImageIndex, ", ", spectrumImagesMap[spkey].properties[propsIndex].ds, " ", dicKey)

	if spectrumImagesMap[spkey].properties[propsIndex].src_ds ~= nil then
		dsImage = loadResizedImage(dicKey)
		return dsImage, dsImage == nil, {key=dicKey, src=spectrumImagesMap[spkey].properties[propsIndex].src_ds}
	end

	local resizeRequired = false
	dsImage = imCacheGet(dicKey)
	if dsImage == nil then
		if fgimg ~= nil then
			-- FIXME:
			-- Odd: it appears that when invoking blitAlpha from the foreground image to the background image,
			-- the foreground image is affected by the alpha value.
			-- For now work around by isolating, blit foreground to a temporary image and then blitAlpha
			-- from the temporary image to the background image
			local tmp = Surface:newRGB(w,h)
			tmp:filledRectangle(0,0,w,h,0)
			fgimg:blit(tmp, 0, 0)
			dsImage = Surface:newRGB(w,h)
			tmp:blitAlpha(dsImage, 0, 0, visSettings.spectrum.decayAlpha)
			tmp:altRelease()
			imCachePut(dicKey, dsImage)
		end
	end
	return dsImage, resizeRequired, nil
end


local prevSpImageIndex = -1
function getSpectrum(_, w, h, barColorIn, capColorIn, capHeightIn, capSpaceIn)
	log:debug("getSpectrum: ", w, " ", h)
	local spkey = spectrumList[spImageIndex].name
	log:debug("getSpectrum: spkey: ", spkey)

	if visSettings.cacheEnabled == false and prevSpImageIndex ~= spImageIndex then
		imCacheClear()
	end
	prevSpImageIndex = spImageIndex

	local rszOp = 0
	local propsIndex = 1
	if spectrumImagesMap[spkey] ~= nil then
		rszOp = spectrumImagesMap[spkey].rszOp
		if visSettings.spectrum.turbine and #spectrumImagesMap[spkey].properties > 1 then
			propsIndex = 2
		end
	end
	local fgImg, fgResizeRequired, rszFg = _getFgSpectrumImage(spkey, w, h, propsIndex)
	local bgImg, bgResizeRequired, rszBg = _getBgSpectrumImage(spkey, w, h, fgImg, propsIndex)
	local dsImg, dsResizeRequired, rszDc = _getDsSpectrumImage(spkey, w, h, fgImg, propsIndex)
	-- resize table must only contain non-nil values
	local rszs={}
	tbl_insert(rszs, rszFg)
	tbl_insert(rszs, rszBg)
	tbl_insert(rszs, rszDc)

	local barColor = spectrumList[spImageIndex].barColor and spectrumList[spImageIndex].barColor or barColorIn
	local capColor = spectrumList[spImageIndex].capColor and spectrumList[spImageIndex].capColor or capColorIn
	local displayResizing = makeResizingParams(fgResizeRequired or bgResizeRequired or dsResizeRequired)
--	local desatColor = spectrumList[spImageIndex].desatColor and spectrumList[spImageIndex].desatColor or 0xffffff30
	local desatColor = 0xffffff30
	if spectrumList[spImageIndex].desatColor ~= nil then
		desatColor = spectrumList[spImageIndex].desatColor
	end

	local capHeight = capHeightIn
	local capSpace = capSpaceIn
	if not visSettings.spectrum.capsOn then
		capHeight = {0,0}
		capSpace = {0,0}
	end
--	return fg, bg, ds, barColor, capColor, desatColor, displayResizing
	local spparms = {
		fgImg=fgImg,
		bgImg=bgImg,
		dsImg=dsImg,
		barColor=barColor,
		capColor=capColor,
		desatColor=desatColor,
		displayResizing=displayResizing,
		channelFlipped=channelFlips[visSettings.spectrum.channelFlip],
		barsFormat=visSettings.spectrum.barFormats[visSettings.spectrum.barsFormat],
		capHeight=((capHeight[1]+capHeight[2])*2)/4,
		capSpace=((capSpace[1]+capSpace[2])*2)/4,
		turbine=visSettings.spectrum.turbine,
		baselineAlways=visSettings.spectrum.baselineAlways,
		baselineOn=visSettings.spectrum.baselineOn,
		fill=visSettings.spectrum.fill,
		rszs=rszs,
		rszOp=rszOp,
	}
	return spparms
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
local vuLoaded = {}
local function _populate25fVuMeterList(search_root)
	if (lfs.attributes(search_root, "mode") ~= "directory") then
		return
	end

	for entry in lfs.dir(search_root) do
		if entry ~= "." and entry ~= ".." then
			local mode = lfs.attributes(search_root .. "/" .. entry, "mode")
			if mode == "directory" then
				local path = search_root .. "/" .. entry
				local jsData = loadJsonFile(path .. "/" .. "meta.json")
				if jsData ~= nil then
					if jsData.kind == "vumeter"
						and vuLoaded[jsData.name] == nil
						and jsData.vutype == "frames" then
						if pathsAreImageFiles(path, jsData.files.frames) == true then
							-- prevent future loading of VUMeter with the same name
							vuLoaded[jsData.name] = true
							log:info("VUMeter frames: ", jsData.name, " framecount:", jsData.framecount)
							for i,_ in ipairs(jsData.files.frames) do
								vuImagesMap[jsData.name .. ":" .. i] = {src= path .. "/" .. jsData.files.frames[i] }
							end
							table.insert(vuImages, {name=jsData.name, enabled=false, displayName=jsData.name, vutype="frames", jsData=jsData})
						else
							log:error("failed to find all images in ", path .. "/" .. "meta.json")
						end
					end
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


local function _init25fLRVuMeterList(rpath)
	for search_root in findPaths(rpath) do
		_populate25fVuMeterList(search_root)
	end
end


local function initVuMeterList()
	vuImages = {}
	vuImagesMap = {}
	vuLoaded = {}

	local relativePath = "assets/visualisers/vumeters/vfd"
	if workSpace ~= System.getUserDir() then
		_populateVfdVuMeterList(workSpace .. "/" .. relativePath)
	end
	_initVfdVuMeterList(relativePath)
	_initVfdVuMeterList("../../" .. relativePath)

	relativePath = "assets/visualisers/vumeters"
	if workSpace ~= System.getUserDir() then
		_populate25fVuMeterList(workSpace .. "/" .. relativePath)
	end
	_init25fVuMeterList(relativePath)
	_init25fVuMeterList("../../" .. relativePath)

	table.sort(vuImages, function (left, right) return left.displayName < right.displayName end)
end

-- Enable at least one valid VU Meter
local function enableOneVUMeter()
		local enabled_count = 0
		-- select a default try to find a vfd (no resize required)
		-- 1: try "Chevrons White Orange"
		for _, v in pairs(vuImages) do
			if v.name == "Chevrons White Orange" and v.vutype=="vfd" then
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
	-- FIXME: workaround. shouldn't be necessary but fixes a corner case
	imCacheClear()
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

	local imgs = {}
	local resizeRequired = false
	for i,_ in ipairs(entry.jsData.files.frames) do
		local dicKey = "for-" .. w .. "x" .. h .. "-" .. entry.name .. ":" .. i
		local frameVU = loadResizedImage(dicKey)
		table.insert(imgs, frameVU)
		resizeRequired = resizeRequired or (frameVU == nil)
	end
	if #imgs < 2 then
		table.insert(imgs, imgs[1])
	end
	return {vutype=entry.vutype, imageFrames=imgs, displayResizing=makeResizingParams(resizeRequired), jsData=entry.jsData}
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
                -- FIXME this test may not be enough
				if spectrumImagesMap[v.name].properties[1].src_fg ~= nil then
					table.insert(spMeters, {name=v.name, w=vr.w, h=vr.h})
				end
			end
		end
	end
	return spMeters
end

function concurrentResizeSpectrumMeter(_, name, w, h)
----	log:info("concurrentResizeSpectrumMeter ", name, ", ", w, ", ", h)
--	for _, v in pairs(spectrumList) do
--		if name == v.name then
--			-- create the resized images for skin resolutions
--			if spectrumImagesMap[v.name].src_fg ~= nil then
--				local path = spectrumImagesMap[v.name].src_fg
--				local dicKey = "for-" .. w .. "x" .. h .. "-" .. name
--				local dcpath = resizedImagePath(dicKey)
--				if resizedImagesTable[dicKey] ~= nil then
--					return true
--				end
--				local ok
--				if v.spType == SPT_BACKLIT then
--					ok = Surface:requestResize(path, dcpath, w, h, 0,
--												RESIZEOP_SCALED_CENTERED_CROP,
--												saveimage_type) == 1
--				elseif v.spType == SPT_IMAGE then
--					ok = Surface:requestResize(path, dcpath, w, h, 0,
--												RESIZEOP_FILL,
--												saveimage_type) == 1
--				else
--					ok = true
--				end
--				if ok then
--					resizedImagesTable[dicKey] = dcpath
--					return true
--				end
--			end
--		end
--	end
	return false
end

function resizeVisualisers(_, w, h, rszs, rszOp)
	local resized = true
	for _, rsz in ipairs(rszs) do
		if resizedImagesTable[rsz.key] == nil then
			local dcpath = resizedImagePath(rsz.key)
			local path = rsz.src
			if Surface:requestResize(path, dcpath, w, h, 0, rszOp, saveimage_type) == 1 then
				resizedImagesTable[rsz.key] = dcpath
			else
				resized = false
			end
		end
	end
	return resized
end

function enumerateResizableVuMeters(_, all)
	local vMeters = {}
	for _, v in pairs(vuImages) do
		if all or v.enabled then
			if v.vutype == "frames" then
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
	-- When VU meters are rendered there are 3 "bars" of spacing,
	-- left, between and right.
	-- resize to 90% of the display window, and all the bars
	-- will visually be the same size.
	-- Note: this only works if the VU Meters do not have any borders along the horizontal axis
	local ok = Surface:requestResize(path, dcpath, math.floor(w*9/10), h, 25,
										RESIZEOP_VU,
										saveimage_type) == 1
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
			if v.vutype == "frames" then
				local ready = true
				for i,_ in ipairs(v.jsData.files.frames) do
					ready = ready and requestVuResize(name .. ':' .. i, w, h)
				end
				return ready
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
