# General
Features:
* Fonts see [README.fonts](README.fonts.md)
* VU Meters
  * Are now rendered by resizing and centering in the available space.
  * VU Meters are now selectable see *Selection* and *Location* below
* Spectrum analyzers:
  * Spectrum analyzers can now be rendered using images as
    * colour gradients
    * foreground image over a background image simulating lighting up vertical bars on an image
  * Spectrum analyzers are also render as coloured bars
  * Spectrum analyzers can be configured see [README.visualiser](./README.visualiserapplet.md)
* Now Playing
  * new views with visualisers have been added
  * controls
    * the complete set of controls displayed is now selectable - Joggler based skins only
    * a new control to cycle visualiser graphics has been added - Joggler based skins only
    * the `\` key cycles the visualiser graphics

The set of available Now Playing Views with visualisers are dependent on the selected skin.

Joggler, PiGrid and Touch skins:
  * `Spectrum Analyzer and Text`
  * `Spectrum Analyzer, Artwork and Text` - smaller spectrum meter
  * `Spectrum Analyzer, Large Artwork and Text` - even smaller spectrum meter
  * `Large Spectrum Analyzer` - full screen spectrum analyzer
  * `Spectrum Analyzer Only` - full screen spectrum analyser - no controls
  * `VU Meter and Text`
  * `VU Meter, Artwork and Text` - smaller vu meters
  * `VU Meter, Large Artwork and Text` - even smaller vu meters
  * `VU Meter Only` full screen - no controls

HD and HDGrid skins:
  * `Spectrum Analyzer and Text`
  * `Spectrum Analyzer, Artwork and Text` - smaller spectrum meter
  * `VU Meter and Text` 
  * `VU Meter, Artwork and Text` - smaller vu meters

The layout of `Artwork and Text` now playing views has been altered for consistency.

# Resizing of VU and Spectrum Meters
Lua code is single threaded and resizing graphic images is usually not instantaneous,
especially on resource constrained targets.

When image resize is performed by lua code - the UI is "stuck" for the duration of the resize operation.

To fix this resizing is done in a thread in native C code, the lua code interacts with the thread 
and displays a resizing animation until the image has been resized and is ready for use.

# VU Meter enhancements
### Details
To provide a timely user experience VU meter images are resized once when
the image is discovered (registered) and stored in a "disk cache" which is at 
`~/.jivelite/userpath/resized_cache`

This avoids repeated resize operations, which may impact UI experience negatively.
The resize operations take a noticeable amount of time especially on resource constrained targets.
See [README.visualiser](./README.visualiserapplet.md)

The trade-off is more disk space is used

**Note:** resizing VU Meters is capped to the resolution of `1280x800`, scaling for larger resolutions crashes Jivelite.

## Selection
It is now possible to change the VU Meter displayed without restarting Jivelite

A menu item `VU Meter Selection` has been added under 
`Settings` -> `Screen` -> `Now Playing` -> `Visualiser`

Multiple VU Meter images may be selected.
The VU meter display is cycled on track change or clicking on the VU meter see [README.visualiser](./README.visualiserapplet.md) for more details
At least one VU Meter image must be selected

There are 3 classes of VU Meters:
 * 25 frames
 * 25 frames LR (frames for left and right meters are different)
 * vfd

## VU Meters
### Location
VU meter images are located here
* `assets/visualisers/vumeters/`

Currently there is no meta-data associated with the VU meter image files.

Jivelite derives the handling required for each VU meter based on the location under the `assets` path.

The schema for location of VU meter images is
`assets/visusalisers/vumeters/<class>/<VU meter name>/`

Where class is one of:
 * 25frames
 * 25framesLR
 * vfd

25 frames VU Meters must be located under  `assets/visualisers/vumeters/25frames`
 * examples:
   * assets/visualisers/vumeters/25frames/TubeD/vu_analog_25seq_daab_Tube.png
   * assets/visualisers/vumeters/25frames/TubeD/vu_analog_25seq_daab_Tube.png.info
25 frames LR VU Meters must be located under `assets/visualisers/vumeters/25framesLR`
 * examples:
   * assets/visualisers/vumeters/25framesLR/Array-4x6-Cyan/Array-4x6-Cyan.info
   * assets/visualisers/vumeters/25framesLR/Array-4x6-Cyan/vu-Array-4x6-Cyan-left.png
   * assets/visualisers/vumeters/25framesLR/Array-4x6-Cyan/vu-Array-4x6-Cyan-right.png

vfd  VU Meters must be location under `assets/visualisers/vumeters/vfd` 
 * examples:
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/bar-off.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/bar-on.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/bar-peak-off.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/bar-peak-on.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/center.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/left-trail.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/left.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/right-trail.png
   * assets/visualisers/vumeters/vfd/Chevrons Cyan Orange/right.png

Note 1: the VU Meter images in this location are in a different form factor from those in
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/VUMeter
 * share/jive/applets/HDSkin/images/UNOFFICIAL/VUMeter

Note 2: the VU Meter images in these location have been trimmed at the top and bottom.
This makes it possible to use the same images as the source for multiple skins and resolutions,
by resizing them to fit the display area.

### Accreditations:
#### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki
artwork files are (packaged by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* ./assets/visualisers/vumeters/25frames/Peppy_Meter_Rainbow/vu_analog_25seq-Peppy_Meter_Rainbow.png
The VU Meter
* ./assets/visualisers/vumeters/25frames/TubeD/vu_analog_25seq_daab_Tube.png
is a derivation of the Peppy Meter Tube VUMeter.

## Digital VU Meters
### VFD
Simulates Vacuum Fluorescent Displays of old.
The images for these VU Meters are located here
* `./assets/visualisers/vumeters/vfd`

These VU meters are resized on demand, as the images are relatively small the resize operation time is not noticeable.
TBD: Details on composition of the VFD. Source code is here ./share/jive/jive/vis/VUMeter.lua

# Spectrum Meter
Spectrum meters can now be rendered using images.
There are 3 classes of spectrum meters
* colour
  * these are predefined in the code
* gradient
  * a custom colour gradient
* backlit
  * simulate lighting up sections of an image in accordance with spectrum values
Spectrum Meter images are selectable see *Selection* and *Location* below

Spectrum layout can be configured see [README.visualiser](./README.visualiserapplet.md) for more details

## Details
Similar to VU Meters, in order to yield a timely user experience Spectrum meter images are resized once when
the image is discovered (registered) and stored in a "disk cache" which is at 
`~/.jivelite/userpath/resized_cache`

## Selection
It is possible to change the Spectrum Meter Image

A menu item `Spectrum Analyzer Selection` has been added under
`Settings` -> `Screen` -> `Now Playing` -> `Visualiser`

Multiple items in the menu may be selected Spectrum meter display is cycled on track change or clicking on the VU meter see [README.visualiser](./README.visualiserapplet.md) for more details.

The logic enforces that at least one item is selected

## Location
Spectrum meter images are enumerated from the locations
 `./assets/visualisers/spectrum/backlit`
 `assets/visualisers/spectrum/gradient`

Currently there is no meta-data associated with the Spectrum meter image files.

Jivelite derives the handling required for each Spectrum meter based on the location under the `assets` path.

The schema for location of VU meter images is
`assets/visusalisers/spectrum/<class>/<Spectrum meter name>/`

Where class is one of:
 * backlit
 * gradient

New Spectrum images can be added simply by copying appropriate files to these locations.

### Resizing
#### Backlit
Images in `.../backlit` are rendered as foreground over a dimmed version as the background.
At the moment that dimming is not configurable from the menu but can be 
adjusted by changing the value of `backgroundAlpha` in

`~/.jivelite/userpath/settings/Visualiser.lua` 

The resizing strategy for these images is the same on both axes to preserve the aspect ratio.
Images will be resized, centered and clipped to fit.

#### Gradient
Images in `.../gradient` and are treated as source images to render spectrum meter as gradients.

The resizing strategy for these images is to expand and compress to fit, without preserving the aspect ratio.
An image consisting of a single vertical line with different colours would suffice.

# Known issues
Resizing images on the target can produce stutters in the UI in the NowPlaying views.

To a large extent this has been addressed by caching the output of resize operations so should occur just once

Even with caching loading a resized image consumes time, and can result in a noticeable delay.

 
# Thanks
Thanks to those involved in creating and maintaining Jivelite,
 * the Logitech team
 * Adrian Smith,  triode1@btinternet.
 * GWENWDESIGN / Felix Mueller
 * presslabs-us
 * Ralph Irving (https://github.com/ralph-irving)
 * Michael Herger (https://github.com/mherger)
