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
* Now Playing Views, new views with visualisers have been added

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

# VU Meter enhancements
### Details
To provide a timely user experience VU meter images are resized once when
the image is discovered (registered) and stored in a "disk cache" which is at 
`~/.jivelite/userpath/resized_cache`
See also [README.pcp](./README.pcp.md)

This avoids repeated resize operations, which may impact UI experience negatively.
The resize operations take a noticeable amount of time especially on low powered raspberry PIs.
See [README.visualiser](./README.visualiserapplet.md)

The trade-off is more disk space is used also see section on piCorePlayer

**Note:** resizing VU Meters is capped to the resolution of `1280x800`, scaling for larger resolutions crashes Jivelite.

## Selection
It is now possible to change the VU Meter displayed without restarting Jivelite

A menu item `Select VU Meter` has been added under
`Settings` -> `Screen` -> `Now Playing` -> `Visualiser`

Multiple VU Meter images may be selected.
The VU meter display is cycled on track change or clicking on the VU meter see [README.visualiser](./README.visualiserapplet.md) for more details
At least one VU Meter image must be selected

## Analogue VU Meters
### Location
VU meter images are locate here
* `assets/visualisers/vumeters/analogue`

New VU Meters can be added simply by copying appropriate files to this location.

The VU Meter images in this location are in a different form factor from those in
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/VUMeter
 * share/jive/applets/HDSkin/images/UNOFFICIAL/VUMeter

The VU Meter images in this location have been trimmed at the top and bottom.
This makes it possible to use the same images as the source for multiple skins and resolutions,
by resizing them to fit the display area.

### Accreditations:
#### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki
artwork files are (packaged by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* ./assets/visualisers/vumeters/analogue/vu_analog_25seq-Peppy_Meter_Rainbow.png
The VU Meter
* ./assets/visualisers/vumeters/analogue/vu_analog_25seq_daab_Tube.png
is derived from ./artwork/vumeters/analogue/vu_analog_25seq-Peppy_Meter_Tube.png

## Digital VU Meters
### VFD
Simulates Vacuum Fluorescent Displays of old.
The images for these VU Meters are located here
* `./assets/visualisers/vumeters/vfd`

These VU meters are resized on demand, as the images are relatively small the resize operation time is not noticeable.
TBD: Details on composition of the VFD. Source code is here ./share/jive/jive/vis/VUMeter.lua

# Spectrum Meter
Spectrum meters can now be rendered using images.
This makes it possible to render spectrum meters as
* a custom colour gradient
* simulate lighting up sections of an image in accordance with spectrum values
Spectrum Meter images are selectable see *Selection* and *Location* below

Spectrum layout can be configured see [README.visualiser](./README.visualiserapplet.md) for more details

## Details
Similar to VU Meters, in order to yield a timely user experience Spectrum meter images are resized once when
the image is discovered (registered) and stored in a "disk cache" which is at 
`~/.jivelite/userpath/resized_cache`
See also [README.pcp](./README.pcp.md)

## Selection
It is possible to change the Spectrum Meter Image

A menu item `Select Spectrum` has been added under
`Settings` -> `Screen` -> `Now Playing` -> `Visualiser`

Multiple items in the menu may be selected Spectrum meter display is cycled on track change or clicking on the VU meter see [README.visualiser](./README.visualiserapplet.md) for more details.

The logic enforces that at least one item is selected

## Location
Spectrum meter images are enumerated from the locations
 `./assets/visualisers/spectrum/backlit`
 `assets/visualisers/spectrum/gradient`

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
