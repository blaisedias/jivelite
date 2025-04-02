#!/usr/bin/env bash

# this script uses imagemagick to convert icons from the material 1k folder to icons
# for the Joggler skin
#
pop_geom="146x146"
case "$1" in
    70)
        # for volume controls height defined at 70
        loc="70"
        geom="45x45"
        vol_geom="34x34"
#        pop_geom="146x146"
        ;;
    100)
        # for volume controls height defined at 100
        loc="100"
        geom="64x64"
        vol_geom="50x50"
#        pop_geom="209x209"
        ;;
    *)
        echo "Usage $0 <40|70|100>"
        exit 1
        ;;
esac

mkdir -p "$loc"


magick convert -resize "$pop_geom" ./1k/skip-next.png $loc/icon_popup_box_fwd.png
magick convert -resize "$pop_geom" ./1k/pause-circle.png  $loc/icon_popup_box_pause.png
magick convert -resize "$pop_geom" ./1k/play-circle.png  $loc/icon_popup_box_play.png
magick convert -resize "$pop_geom" ./1k/repeat-off-5-variant.png  $loc/icon_popup_box_repeat_off.png
magick convert -resize "$pop_geom" ./1k/repeat-variant.png  $loc/icon_popup_box_repeat.png
magick convert -resize "$pop_geom" ./1k/repeat-once-variant.png  $loc/icon_popup_box_repeat_song.png
magick convert -resize "$pop_geom" ./1k/skip-previous.png  $loc/icon_popup_box_rew.png
magick convert -resize "$pop_geom" ./1k/shuffle-album.png  $loc/icon_popup_box_shuffle_album.png
magick convert -resize "$pop_geom" ./1k/shuffle-disabled.png  $loc/icon_popup_box_shuffle_off.png
magick convert -resize "$pop_geom" ./1k/shuffle.png  $loc/icon_popup_box_shuffle.png

magick convert -resize "${1}x${1}" ./1k/control_keyboard_button_press.png  $loc/control_keyboard_button_press.png

magick convert -resize "$geom" ./1k/skip-next.png  $loc/icon_toolbar_ffwd.png
magick convert -resize "$geom" ./1k/DIS-skip-next.png  $loc/icon_toolbar_ffwd_dis.png
magick convert -resize "$geom" ./1k/pause-circle.png  $loc/icon_toolbar_pause.png
magick convert -resize "$geom" ./1k/play-circle.png  $loc/icon_toolbar_play.png
magick convert -resize "$geom" ./1k/repeat-off-5-variant.png  $loc/icon_toolbar_repeat_off.png
magick convert -resize "$geom" ./1k/repeat-variant.png  $loc/icon_toolbar_repeat_on.png
magick convert -resize "$geom" ./1k/repeat-once-variant.png  $loc/icon_toolbar_repeat_song_on.png
magick convert -resize "$geom" ./1k/skip-previous.png  $loc/icon_toolbar_rew.png
magick convert -resize "$geom" ./1k/shuffle-album.png  $loc/icon_toolbar_shuffle_album_on.png
magick convert -resize "$geom" ./1k/DIS-shuffle-disabled.png  $loc/icon_toolbar_shuffle_dis.png
magick convert -resize "$geom" ./1k/shuffle-disabled.png  $loc/icon_toolbar_shuffle_off.png
magick convert -resize "$geom" ./1k/shuffle.png  $loc/icon_toolbar_shuffle_on.png
magick convert -resize "$geom" ./1k/next-visualiser.png  $loc/icon_toolbar_twiddle.png
magick convert -resize "$vol_geom" ./1k/DIS-volume-minus.png  $loc/icon_toolbar_vol_down_dis.png
magick convert -resize "$vol_geom" ./1k/volume-minus.png  $loc/icon_toolbar_vol_down.png
magick convert -resize "$vol_geom" ./1k/DIS-volume-plus.png  $loc/icon_toolbar_vol_up_dis.png
magick convert -resize "$vol_geom" ./1k/volume-plus.png  $loc/icon_toolbar_vol_up.png
