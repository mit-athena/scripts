#!/bin/sh

test=
if [ "$1" = "--test" ]; then
  test="test"
  echo "** TESTING MODE"
fi

if [ "$test" != "test" ]; then
    cd /debathena
fi

pxetype=""

netconfig () {
  echo "Configuring network..."
  mp=/debathena
  if [ "$test" = "test" ]; then
      mp="`dirname $0`/$mp"
  fi
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

  if [ "$pxetype" != cluster ] ; then
    echo -n "Are these OK? [Y/n]: "; read response
    case $response in
      y|Y|"") ;;
      *) 
      echo -n "Netmask bits [$maskbits]: "; read r; if [ "$r" ] ; then maskbits=$r ; fi
      echo -n "Broadcast [$bc]: "; read r; if [ "$r" ] ; then bc=$r ; fi
      echo -n "Gateway [$GATEWAY]: "; read r; if [ "$r" ] ; then GATEWAY=$r ; fi
    esac
  fi

  if [ "$test" != "test" ]; then
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
  fi
}

# Color strings. I'd like to use tput, but the installer doesn't have it.
esc=""
nnn="${esc}[m"          # Normal
ccc="${esc}[36m"        # Cyan
rrr="${esc}[1;31m"      # Bold and red
ddd="${esc}[1;31;47m"   # Plus gray background
ddb="${esc}[1;31;47;5m" # Plus blinking


mirrorsite="mirrors.mit.edu"
installertype="production"
distro="lucid"
arch="i386"
# That is a space and a tab
if egrep -q '^flags[ 	].* lm( |$)' /proc/cpuinfo;  then 
  arch="amd64"
fi


echo "Welcome to Athena."
echo

while [ -z "$pxetype" ] ; do
  echo "Will install $distro ($arch) using $installertype installer and $mirrorsite"
  echo
  echo "Choose one:"
  echo
  echo "  1: Perform an unattended ${ccc}debathena-cluster${nnn} install, ${rrr}ERASING your"
  echo "     ENTIRE DISK${nnn}. This option is only intended for people setting up"
  echo "     public cluster machines maintained by IS&T/Athena. "
  echo
  echo "  2: Do a ${ccc}normal Debathena install${nnn}.  You'll need to answer normal Ubuntu"
  echo "     install prompts, and then the Athena-specific prompts, including"
  echo "     choosing which flavor of Debathena you'd like (e.g., private workstation)."
  echo
  echo "  3: Punt to a completely ${ccc}vanilla install of Ubuntu 10.04${nnn} (Lucid Lynx)."
  echo "     (Note: locale and keyboard have already been set.)"
  echo
  echo "  4: /bin/sh (for rescue purposes)"
  echo
  echo "  Advanced users only:"
  echo "    m: Select a different mirror. "
  echo "    b: Toggle between beta and production installer. "
  echo "    d: Change the distro (version)."
  echo "    a: Change architecture."
  echo
  echo -n "Choose: "
  read r
  case "$r" in
    1)
      echo "Debathena CLUSTER it is."; pxetype=cluster ;;
    1b)
      # This too.
      echo "Debathena CLUSTER it is."; pxetype=cluster
      echo "...but you get to partition by hand. Your hard disk"
      echo "will not be automatically reformatted."; destroys=notreally
      echo
      echo "The default cluster installer sets up:"
      echo " - a 200MB ext3 /boot partition"
      echo " - an LVM volume group named 'athena', containing"
      echo "   - a (3x system RAM)-sized swap LV (at least 512 MB)"
      echo "   - a root LV taking up half the remaining space (at least 10 GB)"
      echo
      echo "You probably want to set up something similar."
      echo "Press enter to continue."
      read r;;
    2)
      echo "Normal Debathena install it is."; pxetype=choose ;;
    3)
      echo "Vanilla Ubuntu it is."; pxetype=vanilla;;
    4)
      echo "Here's a shell.  You'll return to this prompt when done."
      /bin/sh;;
    m|M)
      echo
      echo "NOTE: There is no data validation.  Don't make a typo."
      echo -n "Enter a new mirror hostname: "
      read mirrorsite
      ;;
    d|D)
      echo
      echo "NOTE: There is no data validation.  Don't make a typo."
      echo -n "Enter a new distro: "
      read distro
      ;;
    b|B)
      if [ "$installertype" = "production" ]; then
        echo "Switching to beta installer."
        installertype="beta"
      else
        echo "Switching to production installer."
        installertype="production"
      fi
      ;;
    a|A)
      echo
      oldarch="$arch"
      echo -n "Enter a new arch (acceptable values: i386, amd64): "
      read arch
      if [ "$arch" != "i386" ] && [ "$arch" != "amd64" ]; then
	  echo "Invalid value.  Reverting to $arch."
	  arch="$oldarch"
      fi
      unset oldarch
      ;;
    *)
      echo "Choose one of the above, please.";;
  esac
done

##############################################################################


# Consider setting a static IP address, especially if we can't reach the mirror.
if [ cluster != $pxetype ]; then
  # We're at a point in the install process where we can be fairly sure
  # that nothing else is happening, so "killall wget" should be safe.
  (sleep 5; killall wget >/dev/null 2>&1) &
  if wget -s http://$mirrorsite/ubuntu ; then
    if ip address show to 18.0.0.0/8 | grep -q . && ! ip address show to 18.2.0.0/16 | grep -q . ; then
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

# Fetch secondary (real) installer, invoking as specified above:

echo "Fetching next installer phase..."
# Network config now done above.
if [ "$test" != "test" ]; then
  mkdir /h; cd /h
  wget http://debathena.mit.edu/net-install/kexec
  wget http://debathena.mit.edu/net-install/${distro}/${arch}/initrd.gz
  wget http://debathena.mit.edu/net-install/${distro}/${arch}/linux
  chmod 755 kexec
fi
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
url=http://18.9.60.73/installer/$distro/debathena.preseed \
debathena/pxetype=$pxetype debathena/clusteraddr=$IPADDR \
debathena/i=$installertype debathena/m=$mirrorsite --"

echo "Continuing in five seconds..."
if [ "$test" = "test" ]; then
    echo "Would run kexec with these args:"
    echo "$dkargs $kargs"
    exit 0
fi
./kexec -l linux --append="$dkargs $kargs" --initrd=initrd.gz \
	  && sleep 3 && chvt 1 && sleep 2 && ./kexec -e
echo "Secondary installed failed; please contact release-team@mit.edu"
echo "with the circumstances of your install attempt.  Here's a shell for debugging:"
# We don't want to let this fall through to an actual install of whatever
# kernel we're using.
while : ; do /bin/sh ; done
exit 0
