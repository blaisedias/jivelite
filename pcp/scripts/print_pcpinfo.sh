#!/bin/sh
echo "- System ------------------------------"
uname -a
echo "- Free Space --------------------------"
df -h /mnt/*
echo "- Build -------------------------------"
cat /opt/jivelite/build.txt
echo "- jivelite binary ---------------------"
grep 'src:rev'  /var/log/jivelite.log -A 10
echo "---------------------------------------"
