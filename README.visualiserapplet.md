# Overview
The Visualiser Applet adds the Visualiser setting to the settings screen, with the following menu items:
* **Spectrum Analyzer Settings:**
  * **Bar Format:** Select bar width and spacing between bars.
   Smaller values for bar width and spacing will increase the number of bars - but also increase the load.
  * **Baseline On:** Render the spectrum analyzer baseline when music amplitude is not 0.
  * **Baseline On Always:** Render the spectrum analyzer baseline always. 
  * **Channel Flip:** Select spectrum analyzer bar frequency ordering.
  * **Show Caps:** Display peak caps on spectrum analyzer bars (decaying).
  *Note:* show peak caps does not work if *Turbine* is selected (see below).
  * **Turbine:** Render the spectrum analyzer as bidirectional bars from a baseline which centered vertically.
* **Randomise Visualiser Image Sequence:**
    When multiple spectrum analyzers and VU meters are enabled, the visualiser image selected for display changes when the track changes.
    Selecting this option randomises the sequence in which images are selected.
* **Cache Visualiser Images in RAM:**
    Cache visualiser images in RAM for quick retrieval when changing the visualiser image for display.
 *WARNING* turning this on may result in significant increase memory usage by JiveLite.
 The recommended (and default) setting is OFF.
* **Resize Images:** Manually resize visualiser images so that resized images are available immediately for display in the NowPlaying views.
*Note:* Resize operations are not quick especially for analog VU meters.
Be prepared for significant delays when selecting any of the resize actions below.
  * **Resize Selected Visualiser Images:** Resize all visualiser images (spectrum analyzer and VU meter) the have been selected.
  See *Clear Resized Image Cache* below
  * **Resize Selected Spectrum Images:** Resize selected spectrum analyzer images. 
  * **Resize Selected VU meter Images:** Resize selected VU meter images.
  * **Resize ALL Spectrum Images:** Resize all spectrum analyzer images that have been found.
  * **Resize ALL VU Meter Images:** Resize all VU meter images that have been found.
  * **Resize ALL Visualiser Images:** Resize all Spectrum analyzer and VU meter images that have been found.  
  * **Clear Resized Image Cache:** Clear the cache of discovered resized images. Do this to force resizing of images which have been resized before. Useful if the source image has changed.