#!/bin/sh

# This is only invoked when the relevant preseed entry is passed in
# during the preinstall questioning.  (Thus, not for vanilla installs.)

cp /athena10-intrepid/preseed /target/root/athena10.preseed
cp /athena10-intrepid/install-debathena.sh /target/root
if test -f /athena10-intrepid/pxe-install-flag ; then
  cp /athena10-intrepid/pxe-install-flag /target/root/pxe-install-flag
fi

chvt 5
chroot /target sh /root/install-debathena.sh < /dev/tty5 > /dev/tty5 2>&1
sleep 5
chvt 1
