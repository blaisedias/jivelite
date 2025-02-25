#!/usr/bin/env bash

# this script uses imagemagick to convert icons from the material 1k folder to icons
# for the Joggler skin
#
# icon_toolbar_shuffle_dis.png
# icon_toolbar_vol_down_dis.png
# icon_toolbar_vol_up_dis.png
#
magick convert -resize 146x146 ./1k/skip-next.png icon_popup_box_fwd.png
magick convert -resize 146x146 ./1k/pause-circle.png  icon_popup_box_pause.png
magick convert -resize 146x146 ./1k/play-circle.png  icon_popup_box_play.png
magick convert -resize 146x146 ./1k/repeat-off-5-variant.png  icon_popup_box_repeat_off.png
magick convert -resize 146x146 ./1k/repeat-variant.png  icon_popup_box_repeat.png
magick convert -resize 146x146 ./1k/repeat-once-variant.png  icon_popup_box_repeat_song.png
magick convert -resize 146x146 ./1k/skip-previous.png  icon_popup_box_rew.png
magick convert -resize 146x146 ./1k/shuffle-album.png  icon_popup_box_shuffle_album.png
magick convert -resize 146x146 ./1k/shuffle-disabled.png  icon_popup_box_shuffle_off.png
magick convert -resize 146x146 ./1k/shuffle.png  icon_popup_box_shuffle.png

# for volume controls height defined at 70
geom="45x45"
vol_geom="34x34"

# for volume controls height defined at 100
#geom="64x64"
#vol_geom="50x50""

magick convert -resize "$geom" ./1k/skip-next.png  icon_toolbar_ffwd.png
magick convert -resize "$geom" ./1k/DIS-skip-next.png  icon_toolbar_ffwd_dis.png
magick convert -resize "$geom" ./1k/pause-circle.png  icon_toolbar_pause.png
magick convert -resize "$geom" ./1k/play-circle.png  icon_toolbar_play.png
magick convert -resize "$geom" ./1k/repeat-off-5-variant.png  icon_toolbar_repeat_off.png
magick convert -resize "$geom" ./1k/repeat-variant.png  icon_toolbar_repeat_on.png
magick convert -resize "$geom" ./1k/repeat-once-variant.png  icon_toolbar_repeat_song_on.png
magick convert -resize "$geom" ./1k/skip-previous.png  icon_toolbar_rew.png
magick convert -resize "$geom" ./1k/shuffle-album.png  icon_toolbar_shuffle_album_on.png
magick convert -resize "$geom" ./1k/DIS-shuffle-disabled.png  icon_toolbar_shuffle_dis.png
magick convert -resize "$geom" ./1k/shuffle-disabled.png  icon_toolbar_shuffle_off.png
magick convert -resize "$geom" ./1k/shuffle.png  icon_toolbar_shuffle_on.png
magick convert -resize "$geom" ./1k/next-visualiser.png  icon_toolbar_twiddle.png
magick convert -resize "$vol_geom" ./1k/DIS-volume-minus.png  icon_toolbar_vol_down_dis.png
magick convert -resize "$vol_geom" ./1k/volume-minus.png  icon_toolbar_vol_down.png
magick convert -resize "$vol_geom" ./1k/DIS-volume-plus.png  icon_toolbar_vol_up_dis.png
magick convert -resize "$vol_geom" ./1k/volume-plus.png  icon_toolbar_vol_up.png
