#!/bin/bash

# install debathena into a blank vm, and run tests confirming the install
#
#
# This was developed and tested using VMWare Workstation 9, 
# and mkisofs(2.01)/genisoimage 1.1.11 
#
# example usage:
# -s precise
# -a i386
# -h <vmware host>
# -i (this was tested using a static IP taken from vmnet8)
# -p http://<your preseed>

BASEDIR=.

SUITE=
ARCH=
IP=
HOSTNAME=
PRESEED=

LOGDIR=$BASEDIR/log
NOW=$(date +"%d-%m-%y")
LOG=$LOGDIR/"install-test-"$NOW".log"


function usage() {
  cat<< EO
        Usage:  -s <suite> -a <architecture> -h <hostname> -i <ip> -p <preseed>
EO
}


while getopts "s:a:h:i:p:" OPTION

do
  case $OPTION in
  s)
    SUITE=$OPTARG
    ;;
  a)
    ARCH=$OPTARG
    ;;
  h)
    HOSTNAME=$OPTARG
    ;;
  i)
    IP=$OPTARG
    ;;
  p)
    PRESEED=$OPTARG
    ;;
  ?)
   usage
   exit 1
   ;;
  esac
done

if [[ -z $HOSTNAME || -z $ARCH || -z $PRESEED || -z $IP ]] ; then
  echo "Empty option. HOSTNAME: $HOSTNAME, ARCH: $ARCH, PRESEED: $PRESEED, IP: $IP"  | tee -a $LOG
  usage
  exit 1
fi

if [ -d tmp ] ; then
  rm -rf tmp
fi

mkdir $BASEDIR/tmp
TMPDIR=$BASEDIR/tmp

echo "creating build files..." | tee -a $LOG
cp -R $BASEDIR/isolinux $TMPDIR

echo "fetching kernel and initrd..." | tee -a $LOG
wget -q http://mirrors.mit.edu/ubuntu/dists/$SUITE/main/installer-$ARCH/current/images/netboot/ubuntu-installer/$ARCH/linux -O $TMPDIR/linux
wget -q http://mirrors.mit.edu/ubuntu/dists/$SUITE/main/installer-$ARCH/current/images/netboot/ubuntu-installer/$ARCH/initrd.gz -O $TMPDIR/initrd.gz

ISOLINUXBIN=$TMPDIR/isolinux/isolinux.bin
ISOLINUXBOOT=$TMPDIR/isolinux/boot.cat
ISOLINUXCFG=$TMPDIR/isolinux/isolinux.cfg

# sane?
if [ ! -f $ISOLINUXBIN ] ; then
  echo "isolinux.bin not found at: $ISOLINUXBIN exiting..." | tee -a $LOG
  exit 1
fi

if [ ! -f $ISOLINUXBOOT ] ; then
  echo "boot.cat not found at: $ISOLINUXBOOT exiting..." | tee -a $LOG
  exit 1
fi

if [ ! -f $ISOLINUXCFG ] ; then
  echo "isolinux.cfg not found at: $ISOLINUXCFG exiting..." | tee -a $LOG
  exit 1
fi

echo "seeding isolinux.cfg..." | tee -a $LOG

sed -i "s|%HOSTNAME%|$HOSTNAME|g" $ISOLINUXCFG
sed -i "s|%IP%|$IP|g" $ISOLINUXCFG
sed -i "s|%PRESEED%|$PRESEED|g" $ISOLINUXCFG

echo "creating iso image..." | tee -a $LOG

IMAGENAME=$SUITE-$ARCH-netboot.iso
BUILDDIR=$TMPDIR

mkisofs -r -V "Debathena Boot" \
        -cache-inodes \
        -J -l -b isolinux/isolinux.bin \
        -c isolinux/boot.cat -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o $IMAGENAME $BUILDDIR 2>&1 | tee -a $LOG

if [ ! -f $BASEDIR/$IMAGENAME ] ; then
  echo "iso creation failed. exiting..." | tee -a $LOG
else
  echo "iso creation success..." | tee -a $LOG
fi

echo "installing iso into VM image..." | tee -a $LOG

VMWARE_CONFIG=$BASEDIR/vmware_config

#make vmwware boot out virtual disk / iso
mkdir $TMPDIR/vm
cp -R $VMWARE_CONFIG/* $TMPDIR/vm
mv $BASEDIR/$IMAGENAME $TMPDIR/vm

sed -i "s|%ISO%|$IMAGENAME|g" $TMPDIR/vm/default.vmx

vmrun start $TMPDIR/vm/default.vmx 2>&1 | tee -a $LOG

echo "sleeping for 4 hours before launching tests..." | tee -a $LOG

sleep 240m

ATHINFO_VERSION=`athinfo $IP version`
ATHINFO_VERSION_PASS=`$ATHINFO_VERSION | grep -c debathena-cluster`

if [[ $ATHINFO_VERSION_PASS -ne 1 ]] ; then
  echo "athinfo version returned: $ATHINFO_VERSION. Test Failed." | tee -a $LOG
else
 echo "Test Passed! athinfo version: $ATHINFO_VERSION" | tee -a $LOG
fi

echo "done."

exit 0
