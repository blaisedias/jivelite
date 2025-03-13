local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local Checkbox    	= require("jive.ui.Checkbox")


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {
		scrollText = true,
		scrollTextOnce = false,
		goNowPlayingAtStart = false,
		goNowPlayingAtStartTimer = 5000,
		views = {},
	}
end

function registerApplet(self)
	local settings = self:getSettings()
	if settings.goNowPlayingAtStartTimer == nil then
		settings.goNowPlayingAtStartTimer = 5000
		self:storeSettings()
	end

-- for vis beta 2 remove for release {
-- force display of visualiser meta data
	settings.showVisualiserData=true
	self:storeSettings()
-- }

	local node = { id = 'nowPlayingScrollSettings', iconStyle = 'hm_settings', node = 'screenSettingsNowPlaying',
					text = self:string('SCROLL_SETTINGS'), windowStyle = 'text_only', weight=30  }
	jiveMain:addNode(node)

	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingScrollMode',
			'nowPlayingScrollSettings',
			'SCREENSAVER_SCROLLMODE',
			function(applet, ...)
				applet:scrollSettingsShow(...)
			end,
			40
		)
	)

	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingViewsSettings',
			'screenSettingsNowPlaying',
			'NOW_PLAYING_VIEWS',
			function(applet, ...)
				applet:npviewsSettingsShow(...)
			end, 10
		)
	)

	jiveMain:addItem(
		self:menuItem(
			'scrollStep',
			'nowPlayingScrollSettings',
			'SCROLL_STEP_MINIMUM',
			function(applet, ...)
				applet:inputScrollStepMinimum(...)
			end,
			50
		)
	)

	jiveMain:addItem(
		self:menuItem(
			'scrollFPS',
			'nowPlayingScrollSettings',
			'SCROLL_FPS',
			function(applet, ...)
				applet:inputScrollFPS(...)
			end,
			50
		)
	)

	jiveMain:addItem(
		self:menuItem(
			'fontScrollFactor',
			'nowPlayingScrollSettings',
			'FONT_SCROLL_FACTOR',
			function(applet, ...)
				applet:inputFontScrollFactor(...)
			end,
			50
		)
	)

	local settings = self:getSettings()
	jiveMain:addItem(
		{
			id = 'goNowPlayingAtStart',
			node = 'screenSettingsNowPlaying',
			text = self:string("GO_NOWPLAYING_ON_START"),
			style = 'item_choice',
			weight = 55,
			check =  Checkbox("checkbox", function(_, checked)
				local cb_settings = self:getSettings()
				cb_settings.goNowPlayingAtStart = checked
				self:storeSettings()
			end,
			settings.goNowPlayingAtStart)
		}
	)

	self:registerService('goNowPlaying')
	self:registerService("hideNowPlaying")
	self:registerService("twiddleVisualiser")

end


function configureApplet(self)

	appletManager:callService("addScreenSaver",
		self:string("SCREENSAVER_NOWPLAYING"),
		"NowPlaying",
		"openScreensaver",
		_,
		_,
		10,
		nil,
		nil,
		nil,
		{"whenOff"}
	)

	-- NowPlaying is a resident applet
	appletManager:loadApplet("NowPlaying")

end

