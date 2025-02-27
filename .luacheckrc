files["share/jive/jive/visImage.lua"] = {
   globals = {
       "dumpResizedImagesTable",
       "initialise", "initialiseCache",
       "deleteResizedImages",
       "getSpectrumMeterList", "registerSpectrumResolution", "spChange", "getSpectrum", "isCurrentSpectrumEnabled",
       "getSpectrumMeterSettings", "resizeSpectrumMeter", "getCurrentSpectrumMeterName",
       "selectVuImage", "selectSpectrum",
       "getVuMeterList", "registerVUMeterResolution", "vuChange", "getVuImage", "isCurrentVUMeterEnabled",
       "resizeVuMeter", "getCurrentVuMeterName",
       "resizeRequiredSpectrumMeter", "resizeRequiredVuMeter",
       "getVisualiserChangeOnTimerValue",
       "getWorkspacePath",
       "getDefaultWorkspacePath",
       "setVisSettings",
       "resizeVisualisers",
       "concurrentResizeVuMeter",
       "concurrentResizeSpectrumMeter",
       "enumerateResizableSpectrumMeters",
       "enumerateResizableVuMeters",
   }
}
files["share/jive/jive/vis/SpectrumMeter.lua"] = {
   globals = {
       "__init", "_skin",
       "_layout", "draw",
       "twiddle",
       "FPS", "FC",
   },
   read_globals = {
       "_M", "jive"
   }
}
files["share/jive/jive/vis/VUMeter.lua"] = {
   globals = {
       "__init", "_skin",
       "_layout", "draw",
       "twiddle",
       "FPS", "FC", "NF", "RTZP_VALUES",
   },
   read_globals = {
       "_M", "jive", "appletManager"
   }
}
files["share/jive/applets/NowPlaying/NowPlayingApplet.lua"] = {
   globals = {
       "init",
       "notify_playerShuffleModeChange", "notify_playerDigitalVolumeControl", "notify_playerRepeatModeChange",
       "notify_playerTitleStatus", "notify_playerPower", "notify_playerTrackChange", "notify_playerPlaylistChange",
       "notify_playerModeChange", "notify_playerDelete", "notify_playerCurrent", "notify_skinSelected",
       "_goHomeAction", "_installListeners", "_setPlayerVolume", "_createTitleGroup",
       "npResizeSpectrumMeter", "npResizeVUMeter",
       "goNowPlaying", "hideNowPlaying", "openScreensaver", "showNowPlaying",
       "getNPStyles",
       "invalidateWindow", "adjustVolume", "twiddleVisualiser",
       "free", "freeAndClear",

-- possibly make local always accessed use self:
       "npviewsSettingsShow", "scrollSettingsShow", "setScrollBehavior", "_setVolumeSliderStyle",
       "_setTitleStatus", "changeTitleText", 

-- out of order globals
       "_extractTrackInfo", "_isThisPlayer", "_nowPlayingTrackTransition", "getSelectedStyleParam",
       "removeNowPlayingItem", "addNowPlayingItem", "_titleText", "_updateAll", "_updateButtons",
       "_refreshRightButton", "_remapButton", "_updatePlaylist", "_updateTrack", "_updateProgress",
       "_updatePosition", "_updateVolume", "_updateShuffle", "_updateRepeat", "_updateMode",
       "toggleNPScreenStyle", "replaceNPWindow", "_createUI", "_delayNowPlaying", "_playlistHasTracks",
       "_addScrollSwitchTimer",

   },
   read_globals = {
       "_M", "jive", "appletManager", "jiveMain", "jnt",
   }
}
files["share/jive/applets/Visualiser/VisualiserApplet.lua"] = {
   globals = {
       "init",
       "imagesMenu", "workspaceMenu",
       "selectSpectrumChannelFlip", "selectSpectrumBarsFormat", "selectVuMeters", "selectSpectrumMeters",
       "inputVisualiserChangeOnTimer",
       "resizeImages", "resizeSelectedVisualisers"
   },
   read_globals = {
       "_M", "jive", "appletManager", "jiveMain", "jnt",
   }
}
files["share/jive/applets/Visualiser/VisualiserMeta.lua"] = {
   globals = {
       "jiveVersion", "defaultSettings", "registerApplet", "configureApplet"
   },
   read_globals = {
       "_M", "jive", "appletManager", "jiveMain", "jnt",
   }
}

files["share/jive/applets/Visualiser/VisualiserApplet.lua"] = {
   globals = {
       "init",
   },
   read_globals = {
       "_M", "appletManager", "jiveMain",
   }
}

