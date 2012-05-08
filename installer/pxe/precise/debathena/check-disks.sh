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
