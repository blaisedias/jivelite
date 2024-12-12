# General
Features:
* Fonts see [README.fonts](README.fonts.md)
* VU Meters
  * Are now rendered by resizing and centering in the available space.
  * VU Meters are now selectable see *Selection* and *Location* below
* Spectrum analyzers:
  * Spectrum analyzers can now be rendered using images as
    * reveals, typically colour gradients
    * foreground image over a background image simulating back lighting up vertical bars on an image
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
It is possible to change the VU Meter displayed without restarting Jivelite

A menu item `VU Meter Selection` has been added under 
`Settings` -> `Screen` -> `Now Playing` -> `Visualiser`

Multiple VU Meter images may be selected.
The VU meter display is cycled on track change or clicking on the VU meter see [README.visualiser](./README.visualiserapplet.md) for more details
At least one VU Meter image must be selected

There are 3 classes of VU Meters:
 * 25 frames
 * 25 frames LR (frames for left and right meters are different)
 * composite 

## VU Meters
### Location
VU meter resources are located in subdirectories under
* `assets/visualisers/vumeters/`

Jivelite derives the handling required for each VU meter based on the metadata file `meta.json` associated by location.
For example:
* `assets/visualisers/vumeters/GlowBlue/meta.json`
* `assets/visualisers/vumeters/GlowBlue/vu_analog_25seq_daab_Blue_Glow.png`

The metadata schema for VU meter images is *TO DO*

### Examples:
#### frames
```
{
    "kind": "vumeter",
    "name": "Logitech Black",
    "vutype": "frames",
    "framecount": 25,
    "#format": "single image -> all frames in a single image file",
    "format:": "singleimage",
    "files": {
        "frames": [
            "vu_analog_25seq_Logitech_Black.png"
        ]
    }
}
```
#### frames LR
```
{
    "kind": "vumeter",
    "name": "Array 4x6 Green Red",
    "vutype": "frames",
    "framecount": 25,
    "format:": "singleimage",
    "files": {
        "#channels": "convention first channel is left",
        "frames": [
            "vu-Array-4x6-GreenRed-left.png",
            "vu-Array-4x6-GreenRed-right.png"
        ]
    }
}
```
#### composite
```
{
    "kind": "vumeter",
    "name": "Wings Cyan Orange",
    "vutype": "compose1",
    "files": {
        "bars": [
            {
                "off": [
                    "bar-off.png",
                    "bar-peak-off.png"
                ],
                "on": [
                    "bar-on.png",
                    "bar-peak-on.png"
                ]
            },
            {
                "off": [
                    "r-bar-off.png",
                    "r-bar-peak-off.png"
                ],
                "on": [
                    "r-bar-on.png",
                    "r-bar-peak-on.png"
                ]
            }
        ],
        "centre": "center.png",
        "lead": [
            "left.png",
            "right.png"
        ],
        "trail": [
            "left-trail.png",
            "right-trail.png"
        ]
    },
    "step": 36
}
```

*Note:*
*  The VU Meter images in this location are in a different form factor from those in
   * share/jive/applets/JogglerSkin/images/UNOFFICIAL/VUMeter
   * share/jive/applets/HDSkin/images/UNOFFICIAL/VUMeter
*  The VU Meter images  have been trimmed at the top and bottom.
This makes it possible to use the same images as the source for multiple skins and resolutions,
by resizing them to fit the viewport (display area).

### Accreditations:
#### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki

The following artwork files in artwork/vumeters/25frames are (packaged by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* artwork/vumeters/25frames/vu_analog_25seq-Peppy_Meter_Tube.png
* artwork/vumeters/25frames/vu_analog_25seq-Peppy_Meter_White_and_Red.png
* artwork/vumeters/25frames/vu_analog_25seq-Peppy_Meter_White_and_Red_Rainbow.png
* artwork/vumeters/25frames/vu_analog_25seq-Peppy_Meter_White_and_Red_V2.png

These have not been not included under the `assets` directory, because the calibration does not match that of other VU Meters.

The VU Meter `assets/visualisers/vumeters/TubeD/`
is a derivation of the Peppy Meter Tube VU Meter with calibration consistent with other VU Meters.

## Digital VU Meters
### Compose1
These VU meters are rendered by composition.

The images are relatively small and any resizing operation is performed synchronously, as resize time is not noticeable.

*TO DO*: Details on composition. Source code is here ./share/jive/jive/vis/VUMeter.lua

# Spectrum Meter
Spectrum meters can now be rendered using images.
There are 3 classes of spectrum meters
* colour
  * these are defined in the file `assets/visualisers/spectrum/colours.json`
* image (gradient)
  * sections of the image are "revealed" in accordance with spectrum amplitude values.
* backlit
  * simulate lighting up sections of an image in accordance with spectrum amplitude values.

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
Spectrum meter resources are sub directories under the location
 `./assets/visualisers/spectrum`

Jivelite derives the handling required for each spectrum meter based on the metadata file `meta.json` associated by location.
The metadata schema for Spectrum meter metadata is *TO DO*

### Examples:
#### Colours
```
{
    "kind": "spectrum-meter",
    "sptype": "colour",
    "colours": [
        {
            "name" : "White",
            "barColor" : "0xf0f0f0ff",
            "capColor" : "0xffffffff",
            "desatColor" : "0xc0c0c080"
        },
        {
            "name" : "Yellow",
            "barColor" : "0xffff00ff",
            "capColor" : "0xffff00ff",
            "desatColor" : "0xd0d00080"
        },
        {
            "name" : "Cyan",
            "barColor" : "0x00ffffff",
            "capColor" : "0x00ffffff",
            "desatColor" : "0x00d0d080"
        },
        {
            "name" : "Green",
            "barColor" : "0x00ff00ff",
            "capColor" : "0x00ff00ff",
            "desatColor" : "0x00d00080"
        }
    ]
}
```
#### Backlit
```
{
    "kind": "spectrum-meter",
    "name" : "Psychedelic2",
    "foreground": "background-5421678_1920_inverted.png",
    "sptype": "backlit",
    "backlitAlpha": 64,
    "desatAlpha": 96
}
```
#### Image
```
{
    "kind": "spectrum-meter",
    "name" : "GradientBlueGreenYellowRed",
    "foreground": "BlueGreenYellowRed.png",
    "desaturated": "TspBlueGreenYellowRed.png",
    "sptype": "image",
    "turbine": {
        "foreground": "turbineBlueGreenYellowRed.png",
        "desaturated": "turbineTspBlueGreenYellowRed.png"
    }
}
```

### Resizing
#### Backlit
Images are rendered as foreground over a dimmed version as the background.
At the moment that dimming is not configurable from the menu but can be 
adjusted by changing the value of `backgroundAlpha` in

`~/.jivelite/userpath/settings/Visualiser.lua` 

The resizing strategy for these images is the same on both axes to preserve the aspect ratio.
Images will be resized, centered and clipped to fit.

#### Image
Images are treated as source images to render spectrum meter typically as gradients.

The resizing strategy for these images is to expand and compress to fit, without preserving the aspect ratio.
An image consisting of a single vertical line with different colours would suffice.

# User defined visualisers
User defined visualisers can be added at 
* `/home/<username>/.jivelite/userpath-visu5/assets/visualisers`
  * `spectrum`
  * `vumeters`
* `<workspace>/assets`
  * `spectrum`
  * `vumeters`

The location of files and formats must match that described in the preceding sections.

User defined visualisers replace those included by default if they have the same name.

# Known issues
Resizing images on the target can produce stutters in the UI in the NowPlaying views.

To a large extent this has been addressed by caching the output of resize operations so should occur just once

Occassionally transitioning to a now playing screen, results in sluggish rendering. Cycling through now playing views fixes the rendering.
 
# Thanks
Thanks to those involved in creating and maintaining Jivelite,
 * the Logitech team
 * Adrian Smith,  triode1@btinternet.
 * GWENWDESIGN / Felix Mueller
 * presslabs-us
 * Ralph Irving (https://github.com/ralph-irving)
 * Michael Herger (https://github.com/mherger)
