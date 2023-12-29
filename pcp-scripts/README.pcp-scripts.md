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

Finally storing resized images at this path would also consume RAM space.

To address this the concept of a Jivelite workspace has been introduced.

If a workspace is set Jivelite will save resized images at locations under the workspace.
The intention is set the workspace to point to a location on the piCorePlayer disk - thus avoiding the impact on backup and RAM space.

The trade-off is that Jivelite will now be writing to the piCorePlayer disk.

The presence of a workspace directory was used as an opportunity to make it possible to easily
add custom visualisation artwork and wallpapers for Jivelite in piCorePlayer.

## jivelite.sh.cfg
This version of `jivelite.sh` supports user selection of options, by setting environment variables.

This is done by reading the file `jivelite.sh.cfg` in the locations
* /home/tc
* /mnt/.../tce

A reference version of `jivelite.sh.cfg` with all features turned off 
has been created in this location.

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

Note: this functionality has been tested and verified to work on a single platform,
so may not work on others.

Ideally, touch screen calibration should have been performed and saved prior to this.
