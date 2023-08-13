local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {
		scrollText = true,
		scrollTextOnce = false,
		views = {},
	}
end

function registerApplet(self)

	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingScrollMode', 
			'screenSettingsNowPlaying', 
			'SCREENSAVER_SCROLLMODE', 
			function(applet, ...) 
				applet:scrollSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingViewsSettings', 
			'screenSettingsNowPlaying', 
			'NOW_PLAYING_VIEWS', 
			function(applet, ...) 
				applet:npviewsSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingVUSettings', 
			'screenSettingsNowPlaying', 
			'SELECT_VUMETER', 
			function(applet, ...) 
				applet:npVUSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingSpectrumSettings', 
			'screenSettingsNowPlaying', 
			'SELECT_SPECTRUM', 
			function(applet, ...) 
				applet:npSpectrumSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingSpectrumBarSettings', 
			'screenSettingsNowPlaying', 
			'SPECTRUM_BARS_FORMAT', 
			function(applet, ...) 
				applet:npSpectrumBarSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingSpectrumCapsSettings', 
			'screenSettingsNowPlaying', 
			'SPECTRUM_CAPS', 
			function(applet, ...) 
				applet:npSpectrumCapsSettingsShow(...) 
			end
		)
	)
	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingSpectrumChannelFlipSettings', 
			'screenSettingsNowPlaying', 
			'SPECTRUM_CHANNEL_FLIP', 
			function(applet, ...) 
				applet:npSpectrumChannelFlipSettingsShow(...) 
			end
		)
	)
	self:registerService('goNowPlaying')
	self:registerService("hideNowPlaying")

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

