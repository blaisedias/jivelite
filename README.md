# VU Meter enhancements
**Note this feature has only been implemented for Joggler based skins at this point in time**
* Joggler skin
* PiGrid skins
* Touch skins

## General
VU Meters are now rendered by resizing and centering in the available
space.

VU Meters are now selectable see *Selection* and *Location* below

## Details
To provide a timely user experience VU meter images are resized once when
the image is found once stored as bmp files in a "disk cache" which is at 
`~/.jivelite/userpath/visucache`

Doing it this way avoids repeated resize operations when Jivelite starts up.
The resize operations take a noticeable amount of time especially on low powered raspberry PIs.

The trade-off is more disk space is used.

On piCorePlayer this has the following side-effects
* longer backup times
* larger mydata.tgz files.

On piCorePlayer after the first run or after adding new VU meter images a
backup operation should be performed to benefit from this preprocessing.
If not, Jivelite startup times will be affected adversely.

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

The stock VU meter images have been copied to this location

# Accreditations:
## VU Meter images
### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki
artwork files are (compiled by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_Tube.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red_Rainbow.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq-Peppy_Meter_White_and_Red_V2.png
* share/jive/applets/JogglerSkin/images/UNOFFICIAL/AnalogVUMeters/vu_analog_25seq_Peppy_Meter_Rainbow.png
Note: VU Meter images are resized to render on different resolutions
