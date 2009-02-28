#!/bin/sh

# This could probably all just go in the preseed file, but what a mess!
# 18.9.60.73 = athena10.mit.edu (formerly 18.92.2.195)

cd /
wget http://18.9.60.73/installer/intrepid/athena10-intrepid.tar.gz > /dev/tty5 2>&1
tar xzf athena10-intrepid.tar.gz
chvt 5
sh athena10-intrepid/installer.sh < /dev/tty5 > /dev/tty5 2>&1
chvt 1
# Pick up the generated preseed file (if any):
echo file://athena10-intrepid/preseed
