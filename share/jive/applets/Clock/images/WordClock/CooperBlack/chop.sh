#!/usr/bin/env bash

if [ "$1" == "rows" ] ; then
    convert wordclock-cooper-indestructible.png -crop 762x40+0+12 row1.png
    convert wordclock-cooper-indestructible.png -crop 762x40+0+66 row2.png
    convert wordclock-cooper-indestructible.png -crop 762x40+0+120 row3.png
    convert wordclock-cooper-indestructible.png -crop 762x40+0+174 row4.png
    convert wordclock-cooper-indestructible.png -crop 762x40+0+228 row5.png
    convert wordclock-cooper-indestructible.png -crop 762x40+0+282 row6.png
fi


if [ "$1" == "row1" ] ; then
    convert wordclock-cooper-indestructible.png -crop 50x40+0+12 text-it.png
    convert wordclock-cooper-indestructible.png -crop 50x40+78+12 text-is.png
    convert wordclock-cooper-indestructible.png -crop 100x40+142+12 text-has.png
    convert wordclock-cooper-indestructible.png -crop 198x40+260+12 text-nearly.png
    convert wordclock-cooper-indestructible.png -crop 282x40+474+12 text-justgone.png
fi

if [ "$1" == "row2" ] ; then
    convert wordclock-cooper-indestructible.png -crop 128x40+0+66 text-half.png
    convert wordclock-cooper-indestructible.png -crop 98x40+138+66 text-ten.png
    convert wordclock-cooper-indestructible.png -crop 288x40+242+66 text-aquarter.png
    convert wordclock-cooper-indestructible.png -crop 212x40+546+66 text-twenty.png
fi

if [ "$1" == "row3" ] ; then
    convert wordclock-cooper-indestructible.png -crop 114x40+0+120 text-five.png
    convert wordclock-cooper-indestructible.png -crop 220x40+160+120 text-minutes.png
    convert wordclock-cooper-indestructible.png -crop 68x40+418+120 text-to.png
    convert wordclock-cooper-indestructible.png -crop 120x40+514+120 text-past.png
    convert wordclock-cooper-indestructible.png -crop 82x40+674+120 text-hour-six.png
fi

if [ "$1" == "row4" ] ; then
    convert wordclock-cooper-indestructible.png -crop 160x40+0+174 text-hour-seven.png
    convert wordclock-cooper-indestructible.png -crop 104x40+198+174 text-hour-one.png
    convert wordclock-cooper-indestructible.png -crop 118x40+340+174 text-hour-two.png
    convert wordclock-cooper-indestructible.png -crop 98x40+484+174 text-hour-ten.png
    convert wordclock-cooper-indestructible.png -crop 136x40+622+174 text-hour-four.png
fi

if [ "$1" == "row5" ] ; then
    convert wordclock-cooper-indestructible.png -crop 136x40+0+228 text-hour-five.png
    convert wordclock-cooper-indestructible.png -crop 122x40+170+228 text-hour-nine.png
    convert wordclock-cooper-indestructible.png -crop 200x40+362+228 text-hour-twelve.png
    convert wordclock-cooper-indestructible.png -crop 148x40+610+228 text-hour-eight.png
fi

if [ "$1" == "row6" ] ; then
    convert wordclock-cooper-indestructible.png -crop 190x40+0+282 text-hour-eleven.png
    convert wordclock-cooper-indestructible.png -crop 160x40+206+282 text-hour-three.png
    convert wordclock-cooper-indestructible.png -crop 212x40+378+282 text-oclock.png
    convert wordclock-cooper-indestructible.png -crop 80x40+596+282 text-am.png
    convert wordclock-cooper-indestructible.png -crop 72x40+684+282 text-pm.png
fi


