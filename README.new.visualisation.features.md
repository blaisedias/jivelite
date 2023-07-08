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
  * `Artwork, Text and Analog VU Meter` (mini vu meter)
  * `Artwork, Text and Spectrum Analyzer` (mini spectrum meter)

For consistency of the layout of the `Artwork and Text` now playing viwew has been altered.


# VU Meter enhancements
## Details
To provide a timely user experience VU meter images are resized once when
the image is discovered (registered) and stored as bmp files in a "disk cache" which is at 
`~/.jivelite/userpath/visucache`

Doing it this way avoids repeated resize operations when Jivelite starts up.
The resize operations take a noticeable amount of time especially on low powered raspberry PIs.

The trade-off is more disk space is used also see section on piCorePlayer

**Note:** resizing VUMeters is capped to the resolution of `1280x800`, scaling for larger resolutions crashes Jivelite.

## Selection
It is now possible to change the VU Meter displayed without restarting Jivelite

A menu item `Select VU Meter` has been added under
`Settings` -> `Screen` -> `Now Playing`

Multiple VU Meter images may be selected VU meter display is cycled on track change.
The logic enforces that at least one VU Meter image is selected

## Location
VU meter images are enumerated from the location
 `share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters`

This is primarily to make it possible to use multiple VU Meter images on piCorePlayer 

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
Spectrum Meter images are selectable see *Selection* and *Location* below

Spectrum bar format can now be configured - from a selection of formats.
The list of formats is ordered according to the number of bins the spectrum code generates. Rendering more bins consumes more CPU resource.

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

Typically expansion is the same on both axes to preserve the aspect ratio.

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

TODO: make other parameters such as colours configurable.

The number of columns rendered is a function of the parameters (kudos to authors of that code for making it extensible).
It is possible that increasing the number of columns may overload resource constrained platforms like the Raspberry PI Zero.

The list of presets is ordered so that the number of columns rendered increases further down the list.

# piCorePlayer
On piCorePlayer the image cache is not persistent, between reboots, unless a backup operation is performed - typically using the command 
 * `pcp bu`

Using `filetool.sh` should work as well

The presence of the disk image cache has the side-effects:
* longer backup times
* larger mydata.tgz files
* the disk image cache exists in RAM file-system so consumes RAM

One way to reduce the impact of the disk image cache is to remove images that will not be used from
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/
 * share/jive/applets/JogglerSkin/images/UNOFFICIAL/Spectrum/

Alternatively see `Resizing images prior to deployment` below.

## Resizing images prior to deployment 
It is possible to remove the need for resizing on the target system completely 
by running Jivelite on a desktop or laptop with the desired skin, selecting all
images in VUMeter and Spectrum menus and then copying or moving the images from 

`~/.jivelite/userpath/visucache`

 to

 `jivelite/share/jive/primed-visu-images`

Doing this removes the negative impacts of
 * longer backup times
 * larger mydata.tgz files

# Known issues
* Jivelite gets stuck when trying to render the `Now Playing Views` menu if navigated to from `Home`->`Settings`->`Screen`->`Now Playing` . Unstick by entering now playing and then going back.
* Occasionally now playing view screen starts getting stacked. The trigger for this bug is not known at this point. When this bug triggers clicking on the `back` button `shifts` the view right rather then navigating back up the menu system. Pressing the `back` button repeatedly will eventually navigate back up the menu system.
 
# Thanks
Thanks to those involved in creating Jivelite,
 * the Logitech team
 * GWENWDESIGN / Felix Mueller
 * presslabs-us
 * Adrian Smith,  triode1@btinternet.

Special thanks to Ralph Irving (https://github.com/ralph-irving) and Michael Herger (https://github.com/mherger) for keeping the wheels spinning.
