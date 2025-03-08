# Overview
The Visualiser Applet adds the Visualiser settings with the following menu items:
* **VU Meter Selection:**
Select VU Meters for display - multiple VU Meters can be selected.
* **VU Meter Settings:**
  * **Frames VU Meter RTZ from Peaks:**
    Select the frames VU Meter needle return rate.
* **Spectrum Analyzer Selection:**
Select Spectrum Meters for display - multiple Spectrum Meters can be selected.
* **Spectrum Meter Settings:**
  * **Bar Format:** Select bar width and spacing between bars.
   Smaller values for bar width and spacing will increase the number of bars - but also increase the load.
  * **Baseline On:** Render the spectrum analyzer baseline when music amplitude is not 0.
  * **Baseline On Always:** Render the spectrum analyzer baseline always. 
  * **Channel Flip:** Select spectrum analyzer bar frequency ordering.
  * **Show Caps:** Display peak caps on spectrum analyzer bars (decaying).
  *Note:* show peak caps does not work if *Turbine* is selected (see below).
  * Fill to caps none: space between current level and previous cap is not rendered
  * Fill to caps semi: space between current level and decaying cap value is filled with desaturated colour/image content
  * Fill to caps: space between current level and decaying cap value is filled with "foreground" colour/image content
  * **Turbine:** Render the spectrum analyzer as bidirectional bars from a baseline which centered vertically.
* **Randomise Visualiser Image Sequence:**
    When multiple spectrum analyzers and VU meters are enabled, the visualiser image selected for display changes when the track changes.
    Selecting this option randomises the sequence in which images are selected.
* **Change Visualiser On Track Change**
    Change visualiser graphics when the track changes. This only has an effect when multiple visualiser have been selected. 
* **Cache Visualiser Images in RAM:**
    Cache visualiser images in RAM for quick retrieval when changing the visualiser image for display.
 *WARNING* turning this ON can result in significant increase memory usage by JiveLite, which adversely affect operation of the target device.
 The default setting is OFF, this guarantees stability on resource constrained targets.
* **Change Visualiser On Timer (Seconds)**
    Change visualiser graphics after a fixed period of time. This only has an effect when multiple visualiser have been selected. A value of 0 or none diables this feature.
* **Image Resize:** Manually resize visualiser images so that resized images are available immediately for display in the NowPlaying views.
*Note:* Resize operations are not quick especially for analog VU meters.
Be prepared for significant delays when selecting any of the resize actions below.
  * **Resize Selected Visualiser Images:** Resize all visualiser images (spectrum analyzer and VU meter) the have been selected.
  See *Clear Resized Image Cache* below
  * **Resize Selected Spectrum Images:** Resize selected spectrum analyzer images. 
  * **Resize Selected VU meter Images:** Resize selected VU meter images.
  * **Resize ALL Spectrum Images:** Resize all spectrum analyzer images that have been found.
  * **Resize ALL VU Meter Images:** Resize all VU meter images that have been found.
  * **Resize ALL Visualiser Images:** Resize all Spectrum analyzer and VU meter images that have been found.  
  * **Delete Resized Images:** Clear the cache of discovered resized images. Do this to force resizing of images which have been resized before. Useful if the source image has changed.
  * **Save Resized Images:** Save resized images to disk (default ON)
  * **Save as PNG:** Save resized images as PNGs (default ON)
* **Workspace:** Customise the location where resized images are stored and custom artwork can be added.
See https://github.com/blaisedias/tcz-jivelite/blob/visu-4/README.visu-4.md#persistent-resized-image-cache-on-a-partition
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
