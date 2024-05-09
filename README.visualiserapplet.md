# Overview
The Visualiser Applet adds the Visualiser settings to the Now Playing menu,
with the following menu items:
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
## Bar formats
The bars rendered in the spectrum meter now have limited configurability -
i.e select one from 18 presets.
The parameters are
* number of bars in a bin
* bar width
* bar space
* bin space
the terms used here are derived from the code.
A single column is a `bin`.

A `bin` may have multiple bars. 

`bar space` is the pixel distance between multiple bars (if any).

`bin space` is the pixel distance between the bins.

The number of columns rendered is a function of the parameters (kudos to authors of that code for making it extensible).
It is possible that increasing the number of columns may overload resource constrained platforms like the Raspberry PI Zero.

The list of presets is ordered so that the number of columns rendered increases further down the list.

The set of bar formats can be changed by editing `~/.jivelite/userpath/settings/Visualiser.lua`

# Resize Timings
The table below shows the time taken to resize the set of visualisers
included in this repository on a raspberry PI zero for a screen resolution of 1024x600:
| Type                  | Duration          | 
| --------------------- | ----------------- |
| ALL Spectrum Analyzer | 05 min 11seconds  |
| ALL VU Meters         | 14 min 33seconds  |
| Total                 | 19 min 44 seconds | 
