# credits:
## VU Meter images
### Peppy VU meter images
provided with kind permission by https://github.com/project-owner/PeppyMeter.doc/wiki
list of files are (packaged by @Eyerex https://forums.slimdevices.com/member/65695-eyerex)
* vu_analog_25seq-Peppy_Meter_Tube.png
* vu_analog_25seq-Peppy_Meter_White_and_Red.png
* vu_analog_25seq-Peppy_Meter_White_and_Red_Rainbow.png
* vu_analog_25seq-Peppy_Meter_White_and_Red_V2.png

### Misc
Note: VU Meter images are resized to render on different screen resolutions

Some images have been trimmed using imagemagick

`mogrify -define trim:edges=north,south -trim +repage <image>`

The primary motivation for trimming is to improve the results when resizing VUMeters
for the Now Playing view `Artwork, Text and Analog VU Meter` in particular for the screen
resolution of 800x480.
