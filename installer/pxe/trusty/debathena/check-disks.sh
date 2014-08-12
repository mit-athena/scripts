#!/bin/sh
#
# This is run by d-i before the partman step (e.g. d-i partman/early_command)

MIN_DISK_SIZE=20000000

youlose() {
  chvt 5
  # Steal STDIN and STDOUT back from the installer
  exec < /dev/tty5 > /dev/tty5 2>&1
  echo ""
  echo "****************************"
  echo "ERROR: $@"
  echo "Installation cannot proceed. Press any key to reboot."
  read foo
  echo "Rebooting, please wait..."
  reboot
}

# Unmount partitions because partman and d-i are incompetent.
# http://ubuntuforums.org/showthread.php?t=2215103&p=12977473
# LP: 1355845
for p in $(list-devices partition); do
  umount "$p" || true
done


first_disk=`list-devices disk | head -n1`
if ! echo "$first_disk" | grep -q ^/dev; then
  youlose "No disks found."
fi
if [ "$(sfdisk -s "$first_disk")" -lt $MIN_DISK_SIZE ]; then
  youlose "Your disk is too small ($(( $MIN_DISK_SIZE / 1000000)) GB required)."
fi
# Tell partman which disk to use
debconf-set partman-auto/disk "$first_disk"
exit 0
