# Overview
For now pre-built tcz images are available on google drive see Installation steps below.

* https://drive.google.com/drive/folders/1-yqwfpedEHEOdrOJWuuFtdZsbZQDAxLJ

# Installation
Note: Installing these images overwrites jivelite images and settings,
to restore to stock settings either
* Uninstall JiveLite and install JiveLite again
* Back up jivelite tczs and settings by copying them before installing these images and restoring later
 * `/home/tc/.jivelite`
 * `/mnt/.../tce/optional/*jivelite*`
 
To avoid conflicts in settings it is best to do a clean install.

## Pre-requisites
* pCP version 9.0+
* JiveLite *MUST* be installed using the pCP web interface.
* If required, the display must be setup to work correctly.
  * This version of JiveLite uses display resolution as determined by SDL. See [Display Resolution and skin selection](#display-resolution-and-skin-selection) below. 
* tce partition should have at least 512MiB free space.
* Previous settings - if any should be removed, to do this ssh into pCP and type the following command
```
rm -f /home/blaise/.jivelite/userpath/settings/*
```

## Installation steps
ssh into pCP, then type the following commands
```
ce
wget https://raw.githubusercontent.com/blaisedias/jivelite/visu-3/pcp/scripts/install-visu-3.sh && chmod +x install-visu-3.sh
./install-visu-3.sh
```
A screen similar to below will be presented
```
This script, downloads and installs a forked version of jivelite
on top of an existing installation of jivelite
installation type: 32 bit
installation path: /mnt/mmcblk0p2/tce/optional
If the installation details are correct,
press y then <enter> to proceed with the installation.
Press <enter> to cancel
```
If installation details match press `y` and then `<enter>` to install.

Finally type
```
sudo reboot
```

When pCP restarts the forked version JiveLite will start.

## Post install
After JiveLite has started successfully it is recommended to resize all visualiser images
 see [README.visualiser](../README.visualiserapplet.md) 

This will yield a smoother UI experience.

On a Raspberry PI zero W this will complete in around 20 minutes

Similarly when the skin selection is changed it recommended to resize all visualiser images.

## Version information
Version information is encoded in 2 parts, and can be determined by sshing into pCP
* lua code
 * `cat /opt/jivelite/build.txt`
* jivelite binary
 * `less /var/log/jivelite.log` and search for `src:rev`

The script `/opt/jivelite/pcp/scripts/print_pcpinfo.sh` prints this information in a terminal.

For example
```
tc@raspi-zero-w:~$ /opt/jivelite/pcp/scripts/print_pcpinfo.sh 
- System ------------------------------
Linux raspi-zero-w 6.1.77-pcpCore #12 Wed Feb 14 22:07:56 EST 2024 armv6l GNU/Linux
- Free Space --------------------------
Filesystem                Size      Used Available Use% Mounted on
tmpfs                   386.3M     14.4M    372.0M   4% /
/dev/mmcblk0p2            3.2G      1.0G      2.1G  33% /mnt/mmcblk0p2
- Build -------------------------------
Sun, 12 May 2024 19:28:28 +0100
git remote -v
origin  https://github.com/blaisedias/jivelite.git (fetch)
origin  https://github.com/blaisedias/jivelite.git (push)
git rev-parse HEAD
bf3e266be3b357779526c7357cf0dc004dce10c8
git rev-parse HEAD:share/jive
008038a4087e530c0e82b2510f8bfc89b9a2011a
- jivelite binary ---------------------
JiveLite 0.1.0 src:rev:8d5f8c97c10c11a2b6a7defc84ea4a606d61fbca
features:
        : savePNG
        : fontSelection
        : displaySize
        : altImageLoad
display resolution: 1024x600 BitsPerPixel:32 wmAvailable:0
jiveL_font_default fonts/Nunito/Nunito-Regular.ttf
---------------------------------------
tc@raspi-zero-w:~$ 
```

  
## Display Resolution and skin selection
The display size and presence of Window Manger reported by SDL
is recorded and used selected the skin resolution.

If a Window Manager is not present as on pCP then, the display size is used for screen width and height.

This information is made available at the bottom of the Settings->Screen menu.

Then typically 3 skin choices will be presented
* Grid Skin
* HD Skin
* Joggler Skin

If the display size reported by SDL is >= 1920x1080 the HD Grid Skin will also be available for selection.

Touch skins are absent from the selection because they are Joggler skins with different resolutions.

The resolution reported by SDL may not match the expected values.
For example when connected to a television, SDL reported the resolution as 1824x984 instead of the expected 1920x1080.

The fix is to set the Frame Buffer size to desired resolution using the pCP web interface, Tweaks->Jivelite Setup->Set Size

*Note*: the jivelite binary currently caps the resolution to 1920x1080.

## Image Resize
This version of JiveLite resizes visualisation images to match the display resolution.

Resizing images is not instantaneous and adds significant latency to the user 
interface.

To combat this the output of resizing is cached.

On desktop systems the resized images are cached in
`/home/<username>/.jivelite/userpath/cache/resized`

This caching is persistent across system restarts.

On piCorePlayer this is path not persistent.
If it were made persistent, it would affect backing up adversely in terms of time.

It can be added to the set of paths backed up, and persisted - typically using the command `pcp bu` or `filetool.sh`

However the presence of the disk image cache has the side-effects:
* longer backup times
* larger mydata.tgz files
* the disk image cache exists in RAM file-system so consumes RAM

### Persistent resized image cache on a partition
It is possible to create a persistent resized image cache by changing the location
of the resized image cache to a path on a pCP SD Card.

To address this, the concept of a JiveLite visualiser workspace has been introduced.

If a workspace is set JiveLite will save resized images at locations under the workspace
instead of `/home/<username>/.jivelite/userpath/cache/resized`

The trade-off is that JiveLite will write to the piCorePlayer SD Card when an image is resized.

Saving resized images isn't a frequent activity - it would occur once for each resource image and visualisation viewport combination,
and is deemed a worthy trade-off.

Resize can be done en-block see [README.visualiser](../README.visualiserapplet.md)

The workspace directory can be configured by setting the environment variable `JL_WORKSPACE`.

Set the environment variable `JL_WORKSPACE` to a valid path on the pCP SD Card before starting JiveLite,
and it will then use locations under that path as the resized image cache location.

Support has been added to make this the default, see
* ./pcp/scripts/jivelite.sh 
* ./pcp/scripts/jivelite.sh.cfg

`AUTO_WORKSPACE_SETUP` is set to 1 by default in ./pcp-scripts/jivelite.sh 

The `jivelite.sh` scripts reads that value and then
 * chooses a location as the workspace directory
 * creates the workspace directory - if it does not exist
 * sets `JL_WORKSPACE` to point to the workspace directory

Typically this location is `/mnt/mmcblk0p2/tce/jivelite-workspace`.
This can be verified by looking at `/var/log/jivelite.log`

It should contain lines similar to these
```
auto workspace setup:
workspace: /mnt/mmcblk0p2/tce/jivelite-workspace
```

To use another location as workspace for e.g. on a 3rd partition 
* copy `/opt/jivelite/pcp-scripts/jivelite.sh.cfg` to `/home/tc`
* edit it so that
 * AUTO_WORKSPACE_SETUP=0
 * JL_WORKSPACE="&lt;path&gt;"
   * the path must be an absolute path, for example `/mnt/mmcblk0p3/jivelite/wkspc`

### workspace layout
* `cache/resized` : resized visualisation images are stored here
* `assets` : custom user visualisation can be stored here. The layout is identical to `assets`
  * `assets/visualisers/`
  * `assets/visualisers/spectrum/backlit/`
  * `assets/visualisers/spectrum/gradient/`
  * `assets/visualisers/vumeters/analogue/`
  * `assets/visualisers/vumeters/vfd/`

Alternatively see `Resizing images prior to deployment` below.

## Adding Spectrum Analyzer and VU Meters
The presence of the workspace directory was used as an opportunity to make it easier to adding custom visualisation artwork for JiveLite on piCorePlayer.

Simply copy artwork files to the appropriate location in the workspace path and restart JiveLite.

Typically (but not always) these paths are

* `/mnt/mmcblk0p2/tce/jivelite-workspace/assets/visualisers/spectrum/backlit`
* `/mnt/mmcblk0p2/tce/jivelite-workspace/assets/visualisers/spectrum/gradient`
* `/mnt/mmcblk0p2/tce/jivelite-workspace/assets/visualisers/vumeters/vfd`
* `/mnt/mmcblk0p2/tce/jivelite-workspace/assets/visualisers/vumeters/analogue`

### Resizing images offline
It is possible to remove the need for resizing on the target system completely by rebuilding pcp-jivelite.tcz using squashfs.

Doing this removes the negative impacts of
 * longer backup times
 * larger mydata.tgz files

The procedure is 
* run JiveLite on a desktop or laptop
* select the desired skin and resolution
* resizing all images see [README.visualiser](../README.visualiserapplet.md)
* repeat the previous 2 steps for other skins if applicable
* expand pcp-jivelite.tcz - to get a tree of files and directories
* copy the images from 
  * `~/.jivelite/userpath/resized_cache`
  * TO
  * `opt/jivelite/assets/resized` in the tree created by expanding pcp-jivelite.tcz
* rebuild pcp-jivelite.tcz from the tree
* install the rebuilt pcp-jivelite.tcz

## Touch screen setup
And additional feature implemented in `jivelite.sh` is the *automatic* setup of the touch
screen for JiveLite.

copy `/opt/jivelite/pcp-scripts/jivelite.sh.cfg` to `/home/tc`

The set `AUTO_TOUCHSCREEN_SETUP=1` in `/home/tc/jivelite.sh.cfg` and backup

Note: this functionality has been tested and verified to work on 2 platforms using,
the same touch screen.

Touch screen calibration should have been performed and saved prior to turning this feature ON.

## Stale cache entries
Once a resized image is cached the original artwork will not be loaded again by JiveLite.

If the original  artwork is changed the  cached resized image is now "stale".

To rectify this is to ssh into pCP and delete the resized images.
Resized images have names including the name of the original artwork.

Alternatively,  the JiveLite UI to clear the image cache and resize all images [visualiserapplet](../README.visualiserapplet.md)
# Known issues
Resizing images on the target can produce stutters in the UI in the NowPlaying views.

To a large extent this has been addressed by caching the output of resize operations so should occur just once

Even with caching loading a resized image consumes time, and can result in a noticeable delay.

