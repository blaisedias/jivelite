# Overview
Jivelite resizes visualisation images to match the display resolution if required.

Resizing images is not instantaneous and adds significant latency to the user 
interface.

To combat this the output of resizing is cached.

On desktop systems the resized images are cached in
`/home/<username>/.jivelite/userpath/cache/resized`

This caching is persistent across system restarts.

On piCorePlayer this is path not persistent.
If it were made persistent, it would affect backing up adversely in terms of time.

Also storing resized images at this path consumes RAM space.

To address this, the concept of a Jivelite visualiser workspace has been introduced.

If a workspace is set Jivelite will save resized images at locations under the workspace
instead of `/home/<username>/.jivelite/userpath/cache/resized`

The intention is set the workspace to point to a location on the piCorePlayer disk - thus avoiding the impact on backup and RAM usage.

The trade-off is that Jivelite will now be writing to the piCorePlayer disk,
whenever and image is resized.

This isn't a frequent activity - maximum once for each resource image and visualisation viewport combination.
So is considered a worthy trade-off.

The presence of the workspace directory was used as an opportunity to make it possible to easily
add custom visualisation artwork for Jivelite on piCorePlayer.

## jivelite.sh.cfg
This version of `jivelite.sh` supports user selection of options, by setting environment variables.

This is done by reading the file `jivelite.sh.cfg` in the locations
* /home/tc
* /mnt/.../tce

A reference version of `jivelite.sh.cfg` with all features turned off is included here.
```
# setup touchscreen environment variables TSLIB_TSDEVICE, SDL_MOUSEDRV and TSLIB_CALIBFILE
# set to 1 to enable
AUTO_TOUCHSCREEN_SETUP=0

# workspace : see README.md
# workspace is set as /mnt/.../tce/jivelite-workspace
# set to 1 to enable
AUTO_WORKSPACE_SETUP=0
# For custom workspace set AUTO_WORKSPACE_SETUP=0
#export JL_WORKSPACE=......

# Save resized images to "disk"
export JL_SAVE_RESIZED_IMAGES=false

# Save resized images as PNG instead of BMP
# size saving + proper Alpha channel 
# requires modified jivelite binary
#export JL_SAVE_AS_PNG=true

# WARNING: on resource constrained systems setting the 
# options below to true may result in jivelite terminating
# resize all selected images at startup
#export JL_RESIZE_AT_STARTUP=false

# Modifies behaviour when JL_RESIZE_AT_STARTUP is set
# to resize all images found
#export JL_RESIZE_ALL=false
```

Supported environment variables are
*  `JL_SAVE_RESIZED_IMAGES` set to true to cache the output of resizing for re-use.
*  `JL_SAVE_AS_PNG` set to true to save images as PNGs - smaller and intrinsic support for alpha channel.
*  `JL_RESIZE_AT_STARTUP` resize `selected` visualisation images at startup for smoother user experience
*  `JL_RESIZE_ALL` modify resize at startup to resize all assets that can be found
*  `AUTO_WORKSPACE_SETUP` see `Setting up a workspace` below
*  `JL_WORKSPACE` see `Setting up a workspace` below
*  `AUTO_TOUCHSCREEN_SETUP` see `Touch screen setup` below

Note setting `JL_RESIZE_AT_STARTUP` and `JL_RESIZE_AT_STARTUP` can result in Jivelite terminating
and "restarting" multiple times, on resource constrained platforms - recommendation is not to turn
on these settings.


## Setting up a workspace
A workspace can be set by specifying the path to use in the environment variable
`JL_WORKSPACE`

The accompanying `jivelite.sh` also supports setting up the workspace automatically.
Set `AUTO_WORKSPACE_SETUP=1` in `jivelite.sh.cfg`
The shell script searches for the directory `tce` under `/mnt` and if found,
the directory `/mnt/.../tce/jivelite-workspace` is created.

### workspace layout
* `cache/resized` : resized visualisation images are stored here
* `wallpapers` : custom wallpapers can be added here
* `assets` : custom user visualisation can be stored here. The layout is identical to `assets`
  * `assets/visualisers/`
  * `assets/visualisers/spectrum/`
  * `assets/visualisers/spectrum/backlit/`
  * `assets/visualisers/spectrum/gradient/`
  * `assets/visualisers/vumeters/`
  * `assets/visualisers/vumeters/analogue/`
  * `assets/visualisers/vumeters/vfd/`
  * `assets/visualisers/vumeters/vumeter/`

After images are added to `wallpapers` or under `assets`, Jivelite must be restarted to use the newly added resources.

## Touch screen setup
And additional feature implemented in `jivelite.sh` is the *automatic* setup of the touch
screen for Jivelite.

Set `AUTO_TOUCHSCREEN_SETUP=1` in `jivelite.sh.cfg`

Note: this functionality has been tested and verified to work on 2 platforms using,
the same touch screen.

Touch screen calibration should have been performed and saved prior to turning this feature ON.
