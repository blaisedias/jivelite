#!/usr/bin/env bash

function gen {
    i=1
    echo $1
    echo $2
    magick -size "$2" 'xc:#000000' png32:b.png
    magick b.png "$1" -composite png32:bw.png
# 50%    
#    for x in '#ff0000' '#ff4000' '#ff8000' '#ffbf00' '#ffff00' '#bfff00' '#80ff00' '#40ff00' '#00ff00' '#00ff40' '#00ff80' '#00ffbf' '#00ffff' '#00bfff' '#007fff' '#0040ff' '#0000ff' '#4000ff' '#7f00ff' '#bf00ff' '#ff00ff' '#ff00bf' '#ff0080' '#ff0040';
# 65%    
#    for x in '#ff4d4d' '#ff794d' '#ffa64d' '#ffd24d' '#ffff4d' '#d2ff4d' '#a6ff4d' '#79ff4d' '#4dff4d' '#4dff79' '#4dffa6' '#4dffd2' '#4dffff' '#4dd2ff' '#4da6ff' '#4d79ff' '#4d4dff' '#794dff' '#a64dff' '#d24dff' '#ff4dff' '#ff4dd2' '#ff4da6' '#ff4d79' ;
# 70% 
    for x in '#ff6666' '#ff8c66' '#ffb266' '#ffd966' '#ffff66' '#d9ff66' '#b3ff66' '#8cff66' '#66ff66' '#66ff8c' '#66ffb3' '#66ffd9' '#66ffff' '#66d9ff' '#66b2ff' '#668cff' '#6666ff' '#8c66ff' '#b266ff' '#d966ff' '#ff66ff' '#ff66d9' '#ff66b3' '#ff668c' ;
#    for x in '#ff6666' '#ffd966' '#b3ff66' '#66ff8c' '#66ffff' '#668cff' '#b266ff' '#ff66d9' ;
      do
        magick -size "$2" "xc:$x" png32:x.png
        magick x.png ./bw.png -alpha Off -compose CopyOpacity -composite "c/$i-$1"
        i=$((i+1))
     done
     rm b.png bw.png x.png

 }

gen "text-am.png" "75x40"
gen "text-aquarter.png" "290x37"
gen "text-five.png" "104x38"
gen "text-half.png" "126x37"
gen "text-has.png" "98x37"
gen "text-hour-eight.png" "144x38"
gen "text-hour-eleven.png" "187x40"
gen "text-hour-five.png" "104x38"
gen "text-hour-four.png" "135x39"
gen "text-hour-nine.png" "111x38"
gen "text-hour-one.png" "102x39"
gen "text-hour-seven.png" "161x39"
gen "text-hour-six.png" "78x38"
gen "text-hour-ten.png" "94x39"
gen "text-hour-three.png" "162x40"
gen "text-hour-twelve.png" "199x38"
gen "text-hour-two.png" "112x39"
gen "text-is.png" "42x37"
gen "text-it.png" "41x37"
gen "text-justgone.png" "286x37"
gen "text-minutes.png" "213x38"
gen "text-nearly.png" "196x37"
gen "text-oclock.png" "220x40"
gen "text-past.png" "127x38"
gen "text-pm.png" "68x40"
gen "text-ten.png" "95x37"
gen "text-to.png" "66x38"
gen "text-twenty.png" "204x37"
