#!/bin/sh

function download {
    set -x 
    fileid=$1
    filename=$2
    curl -c ./cookie -s -L "https://drive.google.com/uc?export=download&id=${fileid}" > /dev/null
    curl -Lb ./cookie "https://drive.google.com/uc?export=download&confirm=`awk '/download/ {print $NF}' ./cookie`&id=${fileid}" -o ${filename}
    rm ./cookie
    set +x 
}

#https://drive.google.com/drive/folders/1-yqwfpedEHEOdrOJWuuFtdZsbZQDAxLJ

#https://drive.google.com/file/d/1OdLO-GwDh6SxtQHu-gvAvK76bDCvYScv/view?usp=sharing
PCP_JIVELITE_32BIT="1OdLO-GwDh6SxtQHu-gvAvK76bDCvYScv"
#https://drive.google.com/file/d/1FunVF52Q5xdXJsh5Qf68r04GaHbMzO6s/view?usp=sharing
PCP_JIVELITE_32BIT_MD5="1FunVF52Q5xdXJsh5Qf68r04GaHbMzO6s"
#https://drive.google.com/file/d/1XUh4uwdoK3yEYwlEspaGYS1UueEn5DzU/view?usp=sharing
PCP_JIVELITE_64BIT="1XUh4uwdoK3yEYwlEspaGYS1UueEn5DzU"
#https://drive.google.com/file/d/1RDi9MvvQhY29jRLHtqM1CpFb4bDc7RQa/view?usp=sharing
PCP_JIVELITE_64BIT_MD5="1RDi9MvvQhY29jRLHtqM1CpFb4bDc7RQa"
#https://drive.google.com/file/d/1jrQNnGZa9J2uisWKWJoMrXmyM8NqeK1-/view?usp=sharing
PCP_JIVELITE_HDSKINS="1jrQNnGZa9J2uisWKWJoMrXmyM8NqeK1-"
#https://drive.google.com/file/d/1wDTcaNsD7UXIFsAI1pn49XYQJMWhkval/view?usp=sharing
PCP_JIVELITE_HDSKINS_MD5="1wDTcaNsD7UXIFsAI1pn49XYQJMWhkval"

echo "This script, downloads and installs a forked version of jivelite"
echo "on top of an existing installation of jivelite"
echo ""

case $(uname -m) in
        aarch64)
                echo "installation type: 64 bit"
                ;;
        armv6l | armv7l)
                echo "installation type: 32 bit"
                ;;
        *)
                echo "unable to determine CPU type"
                exit 1
                ;;
esac
TCEMNT="/mnt/$(readlink /etc/sysconfig/tcedir | cut -d '/' -f3)"
TCEOPTIONAL="$TCEMNT/tce/optional"
echo "installation path: $TCEOPTIONAL"
if [ -f "$TCEOPTIONAL/pcp-jivelite.tcz" ];
then
        echo ""
        echo "If the installation details are correct,"
        echo "press y then <enter> to proceed with the installation."
        echo "Press <enter> to cancel"

        IFS= read -r line
        if [ "$line" != "y" ];  then
                echo "cancelling"
                exit 1
        fi

        if [ -d "$TCEOPTIONAL"  ]; then
                cd $TCEOPTIONAL
                echo ""
                echo "checksums of current packages:"
                ls pcp-jivelite* | sort | grep -v .dep | xargs sha1sum
                echo ""
                case $(uname -m) in
                        armv6l | armv7l)
                                download ${PCP_JIVELITE_32BIT} pcp-jivelite.tcz
                                download ${PCP_JIVELITE_32BIT_MD5} pcp-jivelite.tcz.md5.txt
                        ;;
                        aarch64)
                                download ${PCP_JIVELITE_64BIT} pcp-jivelite.tcz
                                download ${PCP_JIVELITE_64BIT_MD5} pcp-jivelite.tcz.md5.txt
                        ;;
                        *)
                                echo "aborting.....unknown architecture"
                                exit 1
                        ;;
                esac
                download ${PCP_JIVELITE_HDSKINS} pcp-jivelite_hdskins.tcz
                download ${PCP_JIVELITE_HDSKINS_MD5} pcp-jivelite_hdskins.tcz.md5.txt
                echo ""
                echo "checksums of new packages"
                ls pcp-jivelite* | sort | grep -v .dep | xargs sha1sum
                echo ""
                echo "now reboot"
        else
            echo "$TCEOPTIONAL not found"
        fi
else
        echo "please install jivelite using pcp before running this script"
fi

