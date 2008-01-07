#!/bin/sh
# This script gets installed in /usr/sbin/policy-rc.d inside template
# chroots.  By exiting 101 ("action not allowed") we suppress any init
# script from starting any daemon from within the chroot.  This is
# standard practice in Debian chroot environments.
exit 101
