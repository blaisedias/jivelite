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


if ! command -v curl &> /dev/null ; then
    echo "please install curl with command \"tce-load -wi curl\""
else
    # 23/10/2023
    if [ -d '../tce/optional' ] ; then
        cd '../tce/optional'
        dl 1uymZv-3JrEAjP-vJi7I2kV9RQQIKngfA "pcp-jivelite_hdskins.tcz"
        dl 1FPkbZ9vb-OhQSc9So-NKrSkQOKsdizai "pcp-jivelite_hdskins.tcz.md5.txt"
        dl 1cW_EMvnsjQzpGG9DwoAUBVhpFdMHefJX "pcp-jivelite.tcz"
        dl 17JRIndz3oBKUKqjcpeQt4Wj3nUyfOEFp "pcp-jivelite.tcz.md5.txt"
    fi
fi

