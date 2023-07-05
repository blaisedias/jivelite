# General
New features have been added for visualisation

**Note these features has only been implemented for Joggler based skins at this point**
* Joggler skin
* PiGrid skins
* Touch skins

Features:
* VU Meters
 * Are now rendered by resizing and centering in the available space.
 * VU Meters are now selectable see *Selection* and *Location* below
* Spectrum meter can now be rendered using images as
 * gradient colours on black background
 * pre-defined gradient 
 * foreground image over background typically simulating lighting up vertical bars of an image
* Now Playing Views, 2 new views have been added
 * Artwork, Text and Analog VU Meter (mini vu meter)
 * Artwork, Text and Spectrum Analyzer (mini spectrum meter)


# VU Meter enhancements
## Details
To provide a timely user experience VU meter images are resized once when
the image is discovered (registered) and stored as bmp files in a "disk cache" which is at 
`~/.jivelite/userpath/visucache`

Doing it this way avoids repeated resize operations when Jivelite starts up.
The resize operations take a noticeable amount of time especially on low powered raspberry PIs.

The trade-off is more disk space is used also see section on piCorePlayer

## Selection
It is now possible to change the VU Meter displayed without restarting Jivelite

A menu item `Select VU Meter` has been added under
`Settings` -> `Screen` -> `Now Playing`

Multiple VU Meter images may be selected VU meter display is cycled on track change.
The logic enforces that at least one VU Meter image is selected

## Location
VU meter images are enumerated from the location
 `share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters`

This is primarily so that using multiple VU Meter images is possible on piCorePlayer 

New VUMeters can be added simply by copying appropriate files to this location.

# Accreditations:
## VU Meter images
### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki
artwork files are (packaged by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_Tube.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red_Rainbow.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red_V2.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq_Peppy_Meter_Rainbow.png

Note: VU Meter images are resized to render on different resolutions

# Spectrum Meter Enhancements
Spectrum meters can now be rendered using images. This makes it possible to render spectrum meters as
* a custom colour gradient
* simulate lighting up sections of an image in accordance with spectrum values
* spectrum bar parameters can now be configured - from a selection of formats

Spectrum Meter images are selectable see *Selection* and *Location* below

## Details
Similar to VUMeters, in order to yield a timely user experience Spectrum meter images are resized once when
the image is discovered (registered) and stored as bmp files in a "disk cache" which is at 
`~/.jivelite/userpath/visucache`


## Selection
It is possible to change the Spectrum Meter Image

A menu item `Select Spectrum` has been added under
`Settings` -> `Screen` -> `Now Playing`

Multiple items in the menu may be selected Spectrum meter display is cycled on track change.
The logic enforces that at least one item is selected

## Location
Spectrum meter images are enumerated from the location
 `share/jive/applets/JogglerSkin/images/UNOFFICIAL/Spectrum`

New Spectrum images can be added simply by copying appropriate files to this location.

Images which with names starting with `fg-` are rendered as foreground over a dimmed version as the background.

All other images are rendered as reveals on a black background.

Resizing strategies of spectrum images for display are different from that use for VUMeters.
Typically expansion is the same on both axes to preserve the aspect ratio 

## Bar formats
The bars rendered in the spectrum meter now have limited configurablility -
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

TODO: make other parameters such as colours configurable.

The number of columns rendered is a function of the parameters (kudos to authors of that code for making it extensible).
It is possible that increasing the number of columns may overload resource constrained platforms like the Raspberry PI Zero.

The list of presets is ordered so that the number of columns rendered increases further down the list.

# piCorePlayer
On piCorePlayer after the first run or after adding new VU meter images a
backup operation should be performed to benefit from this preprocessing.
If not, Jivelite startup times will be affected adversely.

The presence of the disk image cache has the side-effects:
* longer backup times
* larger mydata.tgz files
* more space required for persistent storage
* the disk image cache exists in RAM file-system so consumes RAM

The simplest way to reduce the impact of the disk image cache is to remove images from
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/Spectrum/

Disk image cache sizes (at commit commit d1d15b2dac154efa6b114b50875f1ef1532e5d2f)
 *  800 x 480  - 81 MiB
 * 1024 x 600 - 141 MiB

## Resizing images prior to deployment 
It is possible to remove the need for resizing on the target system compeletely 
by running Jivelite on a desktop or laptop with the desired sking, selecting all
images in VUMeter and Spectrum menus and then copying the images from 
`~/.jivelite/userpath/visucache` to `jivelite/share/jive/primed-visu-images`
Doing this removes the negative impacts of
 * longer backup times
 * larger mydata.tgz files

# Thanks
Thanks to those involved in creating Jivelite,
 * the Logitech team
 * GWENWDESIGN / Felix Mueller
 * presslane-us
 * Adrian Smith,  triode1@btinternet.

Special thanks to Ralph Irving (https://github.com/ralph-irving) and Michael Herger (https://github.com/mherger) for keeping the wheels spinning.
