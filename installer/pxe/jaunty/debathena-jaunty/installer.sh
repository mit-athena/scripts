#!/bin/sh

cd /debathena-jaunty

touch preseed

pxetype=""

# Using debconf here will hang, so parse the command line manually.
# Commented out in the belief that hackbooting *into* the jaunty installer is now always the wrong thing.
# clusterforce=`sed -e 's/ /\n/g' < /proc/cmdline | grep debathena/clusterforce | sed -e 's/.*=//'`
clusteraddr=`sed -e 's/ /\n/g' < /proc/cmdline | grep debathena/clusteraddr | sed -e 's/.*=//'`

if [ "$clusteraddr" ] ; then IPADDR=$clusteraddr ; fi

if [ "$clusteraddr" -a "$clusterforce" = yes ] ; then pxetype=cluster ; fi

netconfig () {
  echo "Configuring network..."
  mp=/debathena-jaunty
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

  if [ "$clusterforce" != yes ] ; then
    echo -n "Are these OK? [Y/n]: "; read response
    case $response in
      y|Y|"") ;;
      *) 
      echo -n "Netmask bits [$maskbits]: "; read r; if [ "$r" ] ; then maskbits=$r ; fi
      echo -n "Broadcast [$bc]: "; read r; if [ "$r" ] ; then bc=$r ; fi
      echo -n "Gateway [$GATEWAY]: "; read r; if [ "$r" ] ; then GATEWAY=$r ; fi
    esac
  fi

  # We can not set the hostname here; running "debconf-set netcfg/get_hostname"
  # causes fatal reentry problems.  Setting values directly with preseeding
  # also fails, as the DHCP values override it.
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
}

# Color strings. I'd like to use tput, but the installer doesn't have it.
esc=""
nnn="${esc}[m"          # Normal
ccc="${esc}[36m"        # Cyan
rrr="${esc}[1;31m"      # Bold and red
ddd="${esc}[1;31;47m"   # Plus gray background
ddb="${esc}[1;31;47;5m" # Plus blinking


echo "Welcome to Athena."
echo

while [ -z "$pxetype" ] ; do
  echo "Choose one:"
  echo
  echo "  1: Perform an unattended ${ccc}debathena-cluster${nnn} install, ${rrr}ERASING your"
  echo "     ENTIRE DISK${nnn}. This option is only intended for people setting up"
  echo "     public cluster machines maintained by IS&T/Athena. If you select"
  echo "     this option, you hereby agree with the license terms at:"
  echo "     <http://dlc.sun.com/dlj/DLJ-v1.1.txt>,"
  echo "     Sun's Operating System Distributor License for Java version 1.1."
  echo
  echo "  2: Do a ${ccc}normal Debathena install${nnn} of Ubuntu 10.04${nnn} (Lucid Lynx)."
  echo "     You'll need to answer normal Ubuntu install prompts, and then the"
  echo "     Athena-specific prompts, including choosing which flavor of Debathena"
  echo "     you'd like (e.g., private workstation)."
  echo
  echo "  3: Punt to a completely ${ccc}vanilla install of Ubuntu 10.04${nnn} (Lucid Lynx)."
  echo "     (Note: locale and keyboard have already been set.)"
  echo
  echo "  4: /bin/sh (for rescue purposes)"
  echo
  echo -n "Choose: "
  read r
  case "$r" in
    1)
      echo "Debathena CLUSTER it is."; pxetype=cluster ;;
    1a)
      echo "Debathena CLUSTER it is, forced to 32-bit."; pxetype=cluster ; arch=i386;;
    2)
      echo "Normal Debathena install it is."; pxetype=choose ;;
    3)
      echo "Vanilla Ubuntu it is."; pxetype=vanilla;;
    4)
      echo "Here's a shell.  You'll return to this prompt when done."
      /bin/sh;;
    9)
      echo "There is no option 9.  Option 1 will do a Lucid cluster install.";;
    *)
      echo "Choose one of the above, please.";;
  esac
done

##############################################################################

if [ -z "$mirrorsite" ] ; then mirrorsite=ubuntu.media.mit.edu ; fi

# Consider setting a static IP address, especially if we can't reach the mirror.
if [ cluster != $pxetype ]; then
  # We're at a point in the install process where we can be fairly sure
  # that nothing else is happening, so "killall wget" should be safe.
  (sleep 5; killall wget >/dev/null 2>&1) &
  if wget -s http://$mirrorsite/ubuntu ; then
    if ip address show to 18/8 | grep -q . && ! ip address show to 18.2/16 | grep -q . ; then
      echo "Your computer seems to be registered on MITnet."
    else
      echo "Your computer seems not to be registered on MITnet, but the mirror"
      echo "site $mirrorsite is accessible."
    fi
    echo
    echo "${ccc}You can continue the install using your existing dynamic address.${nnn}"
    echo -n "Configure a static address anyway?  [y/N]: "
    while : ; do
      read r
      case "$r" in
        N*|n*|"") break;;
        y*|Y*) netconfig; break;;
      esac
      echo -n "Choose: [y/N]: "
    done
  else
    echo "The mirror site $mirrorsite is NOT accessible in your current"
    echo "dynamic configuration."
    echo
    echo "${rrr}You must specify a static address for the installation.${nnn}"
    netconfig
  fi
else
  netconfig
fi

if [ cluster = "$pxetype" ]; then
  if [ notreally != "$destroys" ]; then
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

# Fetch secondary (real) installer, invoking as specified above:
if [ -z "$arch" ] ; then
  if egrep -q '^flags[ 	].* lm( |$)' /proc/cpuinfo
    then arch=amd64 ; else arch=i386
  fi
  echo "Autodetected architecture: $arch."
else
  echo "Forced architecture: $arch."
fi

echo "Initial Debathena setup complete; ready to reboot into main installer."
if ! [ "$clusteraddr" -a "$clusterforce" = yes ] ; then
  echo "Hit return to continue."
  read r
fi

echo "Fetching next installer phase..."
# Network config now done above.
mkdir /h; cd /h
wget http://debathena.mit.edu/net-install/kexec
wget http://debathena.mit.edu/net-install/lucid/${arch}/initrd.gz
wget http://debathena.mit.edu/net-install/lucid/${arch}/linux
chmod 755 kexec
# This is just the guts of the hackboot script:
dkargs="DEBCONF_DEBUG=5"
hname=install-target-host
if [ "$IPADDR" = dhcp ] ; then
  knetinfo="netcfg/get_hostname=$hname "
else
  # There's no good way to get a hostname here, but the postinstall will deal.
  knetinfo="netcfg/disable_dhcp=true \
    netcfg/get_domain=mit.edu \
    netcfg/get_hostname=$hname \
    netcfg/get_nameservers=18.72.0.3 \
    netcfg/get_ipaddress=$IPADDR \
    netcfg/get_netmask=$NETMASK \
    netcfg/get_gateway=$GATEWAY \
    netcfg/confirm_static=true"
fi
kargs="$knetinfo locale=en_US console-setup/layoutcode=us interface=auto \
	  url=http://18.9.60.73/installer/lucid/debathena.preseed \
	  debathena/pxetype=$pxetype debathena/clusteraddr=$IPADDR --"
echo "Continuing in five seconds..."
./kexec -l linux --append="$dkargs $kargs" --initrd=initrd.gz \
	  && sleep 3 && chvt 1 && sleep 2 && ./kexec -e
echo "Secondary installed failed; please contact release-team@mit.edu"
echo "with the circumstances of your install attempt.  Here's a shell for debugging:"
# We don't want to let this fall through to an actual Jaunty install.
while : ; do /bin/sh ; done
