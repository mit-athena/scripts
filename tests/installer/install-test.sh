#!/bin/bash

# Automated testing of Debathena installs
#
# example usage:
# -s precise
# -a i386
# -h <vmware host>
# -b
#  (use beta installer)

# Defaults
SUITE=trusty
ARCH=amd64
HOSTNAME=
INSTALLERTYPE=production
ISOLINUXBIN=/usr/lib/syslinux/isolinux.bin
SCRATCH=/var/vm_scratch
LOGFILE=""

die() {
    echo "$@" >&2
    exit 1
}

stop_qemu() {
    PID=
    if [ -n "$QPIDFILE" ] && \
	[ -r "$QPIDFILE" ]; then
	PID="$(cat $QPIDFILE)"
    else
	echo "QEMU PID file ($QPIDFILE) missing or unreadable" >&2
	return 0
    fi
    if ! echo quit | nc localhost 4444; then
	echo "Couldn't send quit command to monitor! Trying to kill.." >&2
	kill -- "$PID" || :
    fi
    sleep 1
    if kill -0 -- "$PID" 2>/dev/null; then
	echo "Uh oh, QEMU is still running.  You're on your own." >&2
    fi
}

cleanup() {
    rv=$?
    stop_qemu
    if [ -n "$TMPDIR" ]; then
	if [ $rv -ne 0 ]; then
	    echo "Not cleaning up -- investigate remnants in $TMPDIR"
	else
	    rm -rf "$TMPDIR"
	fi
    fi
    exit $rv
}

write_isolinuxcfg() {
    [ -n "$NETCFG" ] && [ -n "$SUITE" ] && [ -n "$INSTALLERTYPE" ]
    cat <<EOF > "$1"
label linux
  kernel ../linux
  append initrd=../initrd.gz $NETCFG locale=en_US keyboard-configuration/layoutcode=us interface=auto url=http://18.9.60.73/installer/$SUITE/debathena.preseed da/pxe=cluster da/i=$INSTALLERTYPE

DEFAULT linux
PROMPT 0
TIMEOUT 0
EOF
}

while getopts "l:bs:a:h:" OPTION; do
  case $OPTION in
  l)
    LOGFILE=$OPTARG
    ;;
  s)
    SUITE=$OPTARG
    ;;
  b)
    INSTALLERTYPE=beta
    ;;
  a)
    ARCH=$OPTARG
    ;;
  h)
    HOSTNAME=$OPTARG
    ;;
  ?)
    echo "Usage: $0 -b -s <suite> -a <architecture> -h <hostname>" >&2
    exit 1
    ;;
  esac
done

[ -n "$HOSTNAME" ] || die "HOSTNAME unspecified"
case "$ARCH" in
    i386|amd64)
	;;
    *)
	die "Unknown arch $ARCH"
	;;
esac
[ -n "$SUITE" ] || die "SUITE unspecified"
[ -f "$ISOLINUXBIN" ] || die "isolinux.bin ($ISOLINUXBIN) missing"

if [ -n "$LOGFILE" ]; then
    if ! [ -d "$(dirname "$LOGFILE")" ]; then
	echo "Logfile directory does not exist" >&2
	exit 1
    fi
    if [ -e "$LOGFILE" ]; then
	echo "$LOGFILE exists, remove it." >&2
    fi
    if ! touch "$LOGFILE"; then
	echo "Could not create logfile $LOGFILE." >&2
	exit 1
    fi
    # Close stdin
    exec < /dev/null

    # Save reference to stdout
    exec 3>&1

    # All output now goes to a log file
    exec >> "$LOGFILE" 2>&1
fi

trap cleanup EXIT

set -ex
TMPDIR=$(mktemp -d --tmpdir="$SCRATCH")

echo -n "Looking up $HOSTNAME ... "
# Ensure this doesn't fail
set +o pipefail
IP=$(dig +short $HOSTNAME | tail -1)
if echo "$IP" | grep -q '[^0-9\.]'; then
    echo "bad IP ($IP)."
    exit 1
else
    echo "IP=$IP"
fi

# Ewww, replace this with netparams ASAP
# and/or add sanity checking to ensure it's on the bridged network
GATEWAY=$(echo "$IP" | awk -F. '{print $1"."$2".0.1"}')

NETCFG="netcfg/disable_autoconfig=true netcfg/get_domain=mit.edu netcfg/get_hostname=$HOSTNAME netcfg/get_nameservers=\"18.72.0.3 18.70.0.160 18.71.0.151\" netcfg/get_ipaddress=$IP netcfg/get_gateway=$GATEWAY netcfg/get_netmask=255.255.0.0 netcfg/confirm_static=true"

ISOROOT="$TMPDIR/iso"
mkdir -p "$ISOROOT/isolinux"
echo "Preparing ISO image..."
cp -v "$ISOLINUXBIN" "$ISOROOT/isolinux"
write_isolinuxcfg "$ISOROOT/isolinux/isolinux.cfg"

echo "Downloading kernel..."
wget -q http://mirrors.mit.edu/ubuntu/dists/$SUITE/main/installer-$ARCH/current/images/netboot/ubuntu-installer/$ARCH/linux -O $ISOROOT/linux
echo "Downloading initrd..."
wget -q http://mirrors.mit.edu/ubuntu/dists/$SUITE/main/installer-$ARCH/current/images/netboot/ubuntu-installer/$ARCH/initrd.gz -O $ISOROOT/initrd.gz

IMAGENAME="$SUITE-$ARCH-netboot.iso"
echo "Creating ISO image..."
mkisofs -r -V "Debathena Boot" \
        -cache-inodes \
        -J -l -b isolinux/isolinux.bin \
        -c isolinux/boot.cat -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$TMPDIR/$IMAGENAME" "$ISOROOT"

[ -f "$TMPDIR/$IMAGENAME" ]

echo "Preparing VM..."
mkdir "$TMPDIR/vm"
echo "Creating hard disk image..."
qemu-img create -f qcow2 "$TMPDIR/vm/sda.img" 30G
QPIDFILE="$TMPDIR/vm/qemu.pid"
echo "Booting vm..."
qemu-system-x86_64 -machine pc,accel=kvm -drive file="$TMPDIR/vm/sda.img",if=virtio -m 4G -netdev bridge,id=hostnet0 -device virtio-net-pci,romfile=,netdev=hostnet0 -cdrom "$TMPDIR/$IMAGENAME" -monitor tcp:localhost:4444,server,nowait -display none -daemonize -pidfile "$QPIDFILE"

echo "Install started at $(date)"
echo -n "Waiting up to 30s for machine networking to come up..."
err=1
for i in $(seq 30); do
    if ping -c 1 -w 2 "$IP" > /dev/null 2>&1; then
	err=0
	echo "ok"
	break
    fi
    echo -n "."
    sleep 1
done
[ $err -eq 1 ] && die "Machine did not respond to ping within 30s"
echo -n "Waiting up to 2m for installer athinfo..."
err=1
for i in $(seq 24); do
    if athinfo -t 1 $HOSTNAME version 2>/dev/null | grep -qi installation; then
	err=0
	echo "ok"
	break
    fi
    echo -n "."
    sleep 5
done
[ $err -eq 1 ] && die "Installer athinfo not present after 2 minutes"
echo -n "Waiting 3h for install to complete..."
err=1
for i in $(seq 36); do
    if athinfo -t 1 $HOSTNAME version 2>/dev/null | grep -qi debathena-cluster; then
	err=0
	echo "ok"
	break
    fi
    echo -n "."
    sleep 5m
done
if [ $err -eq 1 ]; then
    if ping -c 1 -w 2 "$IP" > /dev/null 2>&1; then
	die "Install failed to complete"
    else
	die "Install failed and machine fell off the network!"
    fi
fi
echo "Install successful!"
exit 0
