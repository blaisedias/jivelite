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
       "setVisSettings",
   }
}
files["share/jive/jive/vis/SpectrumMeter.lua"] = {
   globals = {
       "__init", "_skin",
       "_layout", "draw",
       "twiddle",
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
   },
   read_globals = {
       "_M", "jive", "appletManager"
   }
}

