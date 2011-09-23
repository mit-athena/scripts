#!/bin/sh

# Live Poultry Fresh Killed
if grep -q "^Vostro 320" /sys/class/dmi/id/product_name; then
    echo "Scribbling over check-missing-firmware"
    echo > /bin/check-missing-firmware
fi

cd /debathena

touch preseed

pxetype=""

# Using debconf here will hang, so parse the command line manually.
# old options:
#   debathena/clusterforce: implies pxetype=cluster, don't recheck net
#   debathena/clusteraddr: address to use with above
# new options:
#   debathena/pxetype: could be cluster, but could be other things

# support for clusteraddr should be removed sometime in Spring 2012
# Be sure to remove the conditional around line 115 too.
clusteraddr=`sed -e 's/ /\n/g' < /proc/cmdline | grep debathena/clusteraddr | sed -e 's/.*=//'`
pxetype=`sed -e 's/ /\n/g' < /proc/cmdline | grep da/pxe= | sed -e 's/.*=//'`
if [ -z "$pxetype" ]; then
    # Fallback to old-style option for very old machines that haven't
    # updated.  This conditional should be removed sometime in Spring 2012
    pxetype=`sed -e 's/ /\n/g' < /proc/cmdline | grep debathena/pxetype | sed -e 's/.*=//'`
fi
installertype=`sed -e 's/ /\n/g' < /proc/cmdline | grep da/i= | sed -e 's/.*=//'`
mirrorsite=`sed -e 's/ /\n/g' < /proc/cmdline | grep da/m= | sed -e 's/.*=//'`
partitioning=`sed -e 's/ /\n/g' < /proc/cmdline | grep da/part= | sed -e 's/.*=//'`
nodhcp=`sed -e 's/ /\n/g' < /proc/cmdline | grep netcfg/disable_dhcp= | sed -e 's/.*=//'`


echo "Picked up values from command line: 
clusteraddr=$clusteraddr
pxetype=$pxetype
installertype=$installertype
mirrorsite=$mirrorsite"

# Apply some sane defaults
if [ -z "$installertype" ]; then installertype=production ; fi
if [ -z "$mirrorsite" ]; then mirrorsite="mirrors.mit.edu" ; fi

# Sanity check
if [ -z "$pxetype" ]; then 
  echo "ERROR: No pxetype on the command line."
  echo "Cannot proceed.  Reboot now, please."
  read dummy
fi


netconfig () {
  echo "Configuring network..."
  mp=/debathena
  export IPADDR NETMASK GATEWAY SYSTEM CONTROL
  while [ -z "$IPADDR" ] ; do
    echo -n "Enter IP address: "
    read IPADDR
  done
  NETMASK=`$mp/athena/netparams -f $mp/athena/masks $IPADDR|cut -d\  -f 1`
  net=`$mp/athena/netparams -f $mp/athena/masks $IPADDR|cut -d\  -f 2`
  bc=`$mp/athena/netparams -f $mp/athena/masks $IPADDR|cut -d\  -f 3`
  GATEWAY=`$mp/athena/netparams -f $mp/athena/masks $IPADDR|cut -d\  -f 4`
  maskbits=`$mp/athena/netparams -f $mp/athena/masks $IPADDR|cut -d\  -f 5`

  echo "Address: $IPADDR"
  echo
  echo "Autoconfigured settings:"
  echo "  Netmask bits: $maskbits"
  echo "  Broadcast: $bc"
  echo "  Gateway: $GATEWAY"

  echo "Killing dhcp client."
  killall dhclient
  echo "Running: ip addr flush dev eth0"
  ip addr flush dev eth0
  echo "Running: ip addr add $IPADDR/$maskbits broadcast $bc dev eth0"
  ip addr add $IPADDR/$maskbits broadcast $bc dev eth0
  echo "Flushing old default route."
  route delete default 2> /dev/null
  echo "Running: route add default gw $GATEWAY"
  route add default gw $GATEWAY
  echo "Replacing installer DHCP nameserver with MIT nameservers."
  sed -e '/nameserver/s/ .*/ 18.72.0.3/' < /etc/resolv.conf > /etc/resolv.conf.new
  echo "nameserver	18.70.0.160" >> /etc/resolv.conf.new
  echo "nameserver	18.71.0.151" >> /etc/resolv.conf.new
  mv -f /etc/resolv.conf.new /etc/resolv.conf
  echo "Saving preseed netcfg values"
  cat >> preseed <<EOF
d-i netcfg/get_nameservers string 18.72.0.3
d-i netcfg/get_ipaddress string $IPADDR
d-i netcfg/get_netmask string $NETMASK
d-i netcfg/get_gateway string $GATEWAY
d-i netcfg/confirm_static boolean true
EOF
}

# Color strings. I'd like to use tput, but the installer doesn't have it.
esc=""
nnn="${esc}[m"          # Normal
ccc="${esc}[36m"        # Cyan
rrr="${esc}[1;31m"      # Bold and red
ddd="${esc}[1;31;47m"   # Plus gray background
ddb="${esc}[1;31;47;5m" # Plus blinking

# OK, we can arrive at this point in the installer through two
# ways:  from the stage1 installer or from athena-auto-upgrade
# Anything else is an error and will not be supported.
# The stage1 installer takes care of sanity-checking networking
# so if we have a DHCP address here, it's either valid, or we got here
# from an old athena-auto-upgrade that doesn't do full networking.

if [ -n "$clusteraddr" ] && [ "$nodhcp" != "true" ]; then
  IPADDR=$clusteraddr
  netconfig
else
  # We're not running netconfig here, but install-debathena.sh still
  # uses the information from the preseed. So convert information from
  # the kernel command line to the preseed file format.
  sed "s/ /\n/g" < /proc/cmdline | grep "^netcfg" | sed -e "s/^/d-i /" -e "s/=/ string /" >> preseed
fi

# We're at a point in the install process where we can be fairly sure
# that nothing else is happening, so "killall wget" should be safe.
(sleep 5; killall wget >/dev/null 2>&1) &
if wget -s http://$mirrorsite/ubuntu ; then
  if ip address show to 18.0.0.0/8 | grep -q . && ! ip address show to 18.2.0.0/16 | grep -q . ; then
    echo "Network config checks out.  Proceeding..."
  else
    echo "Your computer seems not to be registered on MITnet, but the mirror"
    echo "site $mirrorsite is accessible. Continuing anyway."
  fi
else
  echo "${rrr}The mirror site $mirrorsite is NOT accessible in your current"
  echo "network configuration.  Cannot continue."
  echo "Reboot now."
  read dummy
fi

# Perferred hostname of mirror site
# We want this here even for vanilla installs
cat >> preseed <<EOF
d-i apt-setup/hostname string $mirrorsite
d-i mirror/http/hostname string $mirrorsite
d-i mirror/country string manual
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string
EOF

if [ vanilla = "$pxetype" ] ; then
  echo "Starting normal Ubuntu install in five seconds."
  sleep 5
  exit 0
fi

if [ cluster = "$pxetype" ]; then
  if [ "$partitioning" != "manual" ]; then
    cat << EOF
************************************************************
               ${ddb}DESTROYS${nnn}
${rrr}THIS PROCEDURE ${ddd}DESTROYS${nnn}${rrr} THE CONTENTS OF THE HARD DISK.${nnn}
               ${ddb}DESTROYS${nnn}

IF YOU DO NOT WISH TO CONTINUE, REBOOT NOW.

************************************************************

EOF
    echo "Installing autoinstall preseed file."
    egrep -v '(^$|^#)' < preseed.autoinstall >> preseed
  else
    echo "Installing autoinstall preseed file without automated partitioning."
    egrep -v '(^$|^#|partman)' < preseed.autoinstall >> preseed
  fi
fi

# Shovel in the generically useful preseed stuff regardless.
egrep -v '(^$|^#)' < preseed.common >> preseed


# This is used by the final installer step.
# A hardcoded number is used as DNS may still be iffy.
echo "Fetching Debathena postinstaller."
# 18.92.2.195 = OLD athena10.mit.edu
# 18.9.60.73 = NEW athena10.mit.edu
if [ "$installertype" = "beta" ]; then
  wget http://18.9.60.73/install-debathena.beta.sh
  mv install-debathena.beta.sh install-debathena.sh
else
  wget http://18.9.60.73/install-debathena.sh
fi

# Let the postinstall know what we are up to.
echo "$pxetype" > pxe-install-flag

echo "Initial Debathena installer complete; exiting preconfig to start main install."
if [ "$pxetype" != "cluster" ] || [ "$installertype" = "beta" ]; then
  echo "Hit return to continue."
  read r
fi
exit 0
