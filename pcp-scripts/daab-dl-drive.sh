#!/bin/sh

function dl {
    set -x 
    fileid=$1
    filename=$2
    curl -c ./cookie -s -L "https://drive.google.com/uc?export=download&id=${fileid}" > /dev/null
    curl -Lb ./cookie "https://drive.google.com/uc?export=download&confirm=`awk '/download/ {print $NF}' ./cookie`&id=${fileid}" -o ${filename}
    rm ./cookie
    set +x 
}


if [ "$1" == "32" ] || [ "$1" == "64" ]; then
    if ! command -v curl &> /dev/null ; then
        echo "please install curl with command \"tce-load -wi curl\""
    else
        # 23/10/2023
        if [ -d '../tce/optional' ] ; then
            cd '../tce/optional'
# https://drive.google.com/file/d/1421mxNiMwmpzDyaynUP4DrvuVTDNzA0m/view?usp=sharing pcp-jivelite_hdskins.tcz
            dl 1421mxNiMwmpzDyaynUP4DrvuVTDNzA0m "pcp-jivelite_hdskins.tcz"
# https://drive.google.com/file/d/1_67GNEJIlWkDaphhUAl2W6W8yjwrZJXV/view?usp=sharing pcp-jivelite_hdskins.tcz.md5
            dl 1_67GNEJIlWkDaphhUAl2W6W8yjwrZJXV "pcp-jivelite_hdskins.tcz.md5"
            if [ "$1" == "32" ]; then
                echo "32-bit"
# https://drive.google.com/file/d/1dCI5-aOJrNYWJa55YDAN7sm7L2H64YRM/view?usp=sharing pcp-jivelite.tcz
                dl 1dCI5-aOJrNYWJa55YDAN7sm7L2H64YRM "pcp-jivelite.tcz"
# https://drive.google.com/file/d/12faNftBqYoSQjxt6TB834KFMZm5_fQz1/view?usp=sharing pcp-jivelite.tcz.md5
                dl 12faNftBqYoSQjxt6TB834KFMZm5_fQz1 "pcp-jivelite.tcz.md5"
            else
                echo "64-bit"
# https://drive.google.com/file/d/1hOknRSGSokPgQGV41P6wWNjfor-7oOFC/view?usp=sharing pcp-jivelite.tcz
                dl  1hOknRSGSokPgQGV41P6wWNjfor-7oOFC "pcp-jivelite.tcz"
# https://drive.google.com/file/d/17GeX09OwCsUXzmFmJVHkgkDqa_9-_eGm/view?usp=sharing pcp-jivelite.tcz.md5
                dl  17GeX09OwCsUXzmFmJVHkgkDqa_9-_eGm "pcp-jivelite.tcz.md5"
            fi
        fi
    fi
else
    echo "usage $0 <32|64>"
fi

