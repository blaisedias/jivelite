#!/bin/sh
# modified by daab

export LOG=/var/log/jivelite.log

AUTO_WORKSPACE_SETUP=1
AUTO_TOUCHSCREEN_SETUP=0

if [ -f /usr/local/sbin/config.cfg ]; then
    source /usr/local/sbin/config.cfg
fi

if [ ! -z ${JL_FRAME_BUFFER} ]; then
    export SDL_FBDEV=$JL_FRAME_BUFFER
    echo "Using $SDL_FBDEV as frame buffer device." >> $LOG
fi

if [ -z ${JL_FRAME_RATE} ]; then
    JL_FRAME_RATE=22
fi

export JIVE_FRAMERATE=$JL_FRAME_RATE

echo "Frame rate set to $JIVE_FRAMERATE frames per second." >> $LOG

if [ -z ${JL_FRAME_DEPTH} ]; then
    JL_FRAME_DEPTH=32
fi

/usr/sbin/fbset -depth $JL_FRAME_DEPTH >> $LOG
 
echo "Frame buffer color bit depth set to $JL_FRAME_DEPTH." >> $LOG

if [ ! -z ${SDL_TOUCHSCREEN} ]; then
    export JIVE_NOCURSOR=1
fi

export HOME=/home/tc

if [ -f /home/tc/jivelite.sh.cfg ]; then
    echo "using /home/tc/jivelite.sh.cfg" >> $LOG
    cat "/home/tc/jivelite.sh.cfg" >> $LOG
    source /home/tc/jivelite.sh.cfg >> $LOG
fi

TCEMNT="/mnt/$(readlink /etc/sysconfig/tcedir | cut -d '/' -f3)"
TCEDIR="${TCEMNT}/tce"
if [ -f "${TCEDIR}/jivelite.sh.cfg" ]; then
    echo "using ${TCEDIR}/jivelite.sh.cfg" >> $LOG
    cat "${TCEDIR}/jivelite.sh.cfg" >> $LOG
    source "${TCEDIR}/jivelite.sh.cfg" >> $LOG
fi

if [ "${AUTO_TOUCHSCREEN_SETUP}" == "1" ]; then
    echo "auto touch screen setup:" >> $LOG
    ev=$(cat /proc/bus/input/devices | grep mouse | sed -e 's# $##' -e 's#^.* ##')
    if [ "$ev" != "" ] ; then
        echo "using mouse input device: $ev" >> $LOG
        export TSLIB_TSDEVICE=/dev/input/$ev
        export SDL_MOUSEDRV=TSLIB
    fi
    if [ -f '/usr/local/etc/pointercal' ] ; then
        echo "using user configured pointer calibration" >> $LOG
        export TSLIB_CALIBFILE=/usr/local/etc/pointercal
    fi
fi

if [ "${AUTO_WORKSPACE_SETUP}" == "1" ] && [ "$JL_WORKSPACE" == "" ]; then
    echo "auto workspace setup:" >> $LOG
    if [ -z $JL_WORKSPACE ]; then
        export JL_WORKSPACE="${TCEDIR}/jivelite-workspace"
        echo "workspace: $JL_WORKSPACE" >> $LOG
        if [ ! -d "$JL_WORKSPACE" ]; then
                echo  "mkdir -p $JL_WORKSPACE" >> $LOG
                mkdir -p $JL_WORKSPACE
        fi
    fi
fi

while true; do
    sleep 3
    LD_LIBRARY_PATH=/opt/jivelite/lib/ /opt/jivelite/bin/jivelite >> $LOG 2>&1
done
