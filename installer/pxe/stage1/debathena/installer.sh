#!/bin/sh

dnscgi="http://18.9.60.73/website/dns.cgi"

test=
if [ "$1" = "--test" ]; then
  test="test"
  echo "** TESTING MODE"
fi

if [ "$test" != "test" ]; then
    cd /debathena
fi

debug () {
  if [ "$test" != "test" ]; then
    logger -t install.debug "$@"
  else
    echo "DEBUG: $@"
  fi
}

pxetype=""

netconfig () {
  echo "Configuring network..."
  mp=/debathena
  if [ "$test" = "test" ]; then
      mp="`dirname $0`"
  fi
  export IPADDR NETMASK GATEWAY SYSTEM CONTROL HOSTNAME
  # This will fail if dhreg addresses ever stop being able to reach net 18
  # First make sure we're talking to who we think we are
  havedns=n
  ipprompt="Enter IP address:"
  if [ "$(wget -qO - "$dnscgi/q")" = "Debathena DNS-CGI" ]; then
    havedns=y
    ipprompt="Enter IP address or hostname:"
  fi

  while [ -z "$IPADDR" ] ; do
    HOSTNAME=
    echo -n "$ipprompt "
    read IPADDR
    debug "In netconfig, user entered '$IPADDR'"
    # RFC1123 does permit hostnames to start with digits, moira doesn't
    # If you do that, suck it up and type the IP
    if echo "$IPADDR" | grep -q '[a-zA-Z]'; then
      HOSTNAME="$IPADDR"
      IPADDR=
      if [ "$havedns" != "y" ]; then
	echo "Enter a valid IP address.  (DNS not available)".
	continue
      fi
      echo "Looking up IP for $HOSTNAME..."
      dig="$(wget -qO - "$dnscgi/a/$HOSTNAME")"
      if echo "$dig" | grep -q '^OK:'; then
	IPADDR="$(echo "$dig" | sed 's/^OK: //')"
	echo "Found $IPADDR..."
      else
	echo "$dig"
	echo "Could not look up IP address for $HOSTNAME.  Try again."
      fi
    fi
  done

  if [ -z "$HOSTNAME" ] && [ "$havedns" = "y" ]; then
    dig="$(wget -qO - "$dnscgi/ptr/$IPADDR")"
    if echo "$dig" | grep -q '^OK:'; then
      HOSTNAME="$(echo "$dig" | sed 's/^OK: //')"
      echo "$IPADDR reverse-resolves to $HOSTNAME..."
    else
      echo "$dig"
      echo "Could not look up hostname for $IPADDR."
      echo "Cannot continue without a valid hostname."
      echo "Please note that if this address was newly requested,"
      echo "or its hostname was changed, it can take up to 2 business days"
      echo "before DNS information is correct."
      echo 
      echo "Please try again once DNS has been updated or use a different"
      echo "IP address.  You may now restart or shut down this workstation."
      while true; do
	  read foo
	  if [ "$foo" = "xyzzy" ]; then 
	      break
	  fi
      done
    fi
  fi
  if [ -z "$HOSTNAME" ]; then
      HOSTNAME=install-target-host
  fi
  
  HOSTNAME="$(echo "$HOSTNAME" | tr A-Z a-z | sed 's/\.mit\.edu$//')"

  NETMASK=`$mp/athena/netparams -f $mp/athena/masks "$IPADDR"|cut -d\  -f 1`
  net=`$mp/athena/netparams -f $mp/athena/masks "$IPADDR"|cut -d\  -f 2`
  bc=`$mp/athena/netparams -f $mp/athena/masks "$IPADDR"|cut -d\  -f 3`
  GATEWAY=`$mp/athena/netparams -f $mp/athena/masks "$IPADDR"|cut -d\  -f 4`
  maskbits=`$mp/athena/netparams -f $mp/athena/masks "$IPADDR"|cut -d\  -f 5`

  echo "Address: $IPADDR"
  echo
  echo "Autoconfigured settings:"
  echo "  Netmask bits: $maskbits"
  echo "  Broadcast: $bc"
  echo "  Gateway: $GATEWAY"

  debug "Calculated values: $HOSTNAME $NETMASK $GATEWAY $bc"

  if [ "$pxetype" != cluster ] ; then
    echo -n "Are these OK? [Y/n]: "; read response
    case $response in
      y|Y|"") ;;
      *) 
      echo -n "Netmask bits [$maskbits]: "; read r; if [ -n "$r" ] ; then maskbits=$r ; fi
      echo -n "Broadcast [$bc]: "; read r; if [ -n "$r" ] ; then bc=$r ; fi
      echo -n "Gateway [$GATEWAY]: "; read r; if [ -n "$r" ] ; then GATEWAY=$r ; fi
    esac
  fi

  if [ "$test" != "test" ]; then
  # We can not set the hostname here; running "debconf-set netcfg/get_hostname"
  # causes fatal reentry problems.  Setting values directly with preseeding
  # also fails, as the DHCP values override it.
  echo "Killing dhcp client."
  killall dhclient
  ETH0="$(ip -o link show | grep -v loopback | cut -d: -f 2 | tr -d ' ')"
  echo "Running: ip addr flush dev $ETH0"
  ip addr flush dev $ETH0
  echo "Running: ip addr add $IPADDR/$maskbits broadcast $bc dev $ETH0"
  ip addr add "$IPADDR/$maskbits" broadcast "$bc" dev $ETH0
  echo "Flushing old default route."
  route delete default 2> /dev/null
  echo "Running: route add default gw $GATEWAY"
  route add default gw "$GATEWAY"
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
distro="precise"
partitioning="auto"
arch="i386"
# That is a space and a tab
if egrep -q '^flags[ 	].* lm( |$)' /proc/cpuinfo;  then 
  arch="amd64"
fi

# Of course the installer doesn't have `date`
# time.mit.edu/kerberos.mit.edu is 18.7.21.144
# This will probably break eventually
debug "** Install begins at $(nc -w1 18.7.21.144 13)"

if [ -f "/debathena/version" ]; then
  echo -n "SVN version: " && cat /debathena/version
  debug "SVN: " "$(cat /debathena/version)"
fi

debug "Mirror $mirrorsite Type $installertype Arch $arch"

echo "Welcome to Athena, Stage 1 Installer"
echo

while [ -z "$pxetype" ] ; do
  echo
  echo "Will install ${ccc}$distro${nnn} ($arch) using $installertype installer"
  echo "from $mirrorsite using $partitioning partitioning"
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
  echo "  3: Punt to a completely ${ccc}vanilla install of Ubuntu${nnn}."
  echo "     (Note: locale and keyboard have already been set.)"
  echo
  echo "  4: /bin/sh (for rescue purposes)"
  echo
  echo "  Advanced users only:"
  echo "    m: Select a different mirror. "
  echo "    b: Toggle between beta and production installer. "
  echo "    d: Change the distro (version)."
  echo "    a: Change architecture."
  echo "    p: Toggle between manual and auto partitioning. "
  echo
  echo -n "Choose: "
  read r
  case "$r" in
    1)
      echo "Debathena CLUSTER it is."; pxetype=cluster ;;
    2)
      echo "Normal Debathena install it is."; pxetype=choose ;;
    3)
      echo "Vanilla Ubuntu it is."; pxetype=vanilla;;
    4)
      echo "Here's a shell.  You'll return to this prompt when done."
      echo
      echo "Note: This shell has no job control, and unless you know"
      echo "what you're doing, you almost certainly want to switch to"
      echo "VT2 (by pressing Ctrl-Alt-F2), and use the shell there."
      echo "You can return to this screen (VT5) by pressing Ctrl-Alt-F5."
      echo
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
    p|P)
      if [ "$partitioning" = "auto" ]; then
        echo "Switching to manual partitioning."
	echo "Your disk will (probably) not be erased."
        partitioning="manual"
	echo "Normally, cluster machines get:"
	echo " - a 200MB ext3 /boot partition"
	echo " - an LVM volume group named 'athena', containing"
	echo "   - a (3x system RAM)-sized swap LV (at least 512 MB)"
	echo "   - a root LV taking up half the remaining space (at least 10 GB)"
	echo
	echo "You probably want to set up something similar."
	echo
	echo "Backups are ALWAYS a good idea.  Stop and make one now."
	echo "Press Enter to continue."
	read dummy
      else
        echo "Switching to auto partitioning."
        partitioning="auto"
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

debug "*** Main menu complete"
debug "Mirror: $mirrorsite Type: $installertype Part: $partitioning"
debug "Arch: $arch Distro: $distro Pxetype: $pxetype"
debug "$ETH0:"
debug "$(ip address show $ETH0)"
debug "routing:"
debug "$(route)"
debug "resolv.conf:"
debug "$(cat /etc/resolv.conf)"

##############################################################################


# Consider setting a static IP address, especially if we can't reach the mirror.
if [ cluster != "$pxetype" ]; then
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

if [ "$pxetype" = "cluster" ] && [ "$partitioning" = "auto" ]; then
    cat << EOF
************************************************************
               ${ddb}DESTROYS${nnn}
${rrr}THIS PROCEDURE ${ddd}DESTROYS${nnn}${rrr} THE CONTENTS OF THE HARD DISK.${nnn}
               ${ddb}DESTROYS${nnn}

IF YOU DO NOT WISH TO CONTINUE, REBOOT NOW.

************************************************************
EOF
fi
echo
echo "Installer configuration complete.  Press Enter to begin"
echo "or reboot your workstation now to abort installation."
read r

# Fetch secondary (real) installer, invoking as specified above:

echo "Fetching next installer phase..."
# Network config now done above.
if [ "$test" != "test" ]; then
  mkdir /h; cd /h
  wget "http://debathena.mit.edu/net-install/kexec"
  wget "http://debathena.mit.edu/net-install/${distro}/${arch}/initrd.gz"
  wget "http://debathena.mit.edu/net-install/${distro}/${arch}/linux"
  chmod 755 kexec
fi
dkargs="DEBCONF_DEBUG=5"

nodhcp="netcfg/disable_dhcp=true"
case "$distro" in
    oneiric|precise)
        kbdcode="keyboard-configuration/layoutcode=us"
        # "Yay"
        nodhcp="netcfg/disable_autoconfig=true"
	;;
    natty)
        # Sigh
        kbdcode="keyboard-configuration/layoutcode=us"
        ;;
    *)
        kbdcode="console-setup/layoutcode=us"
        ;;
esac

hname="$HOSTNAME"
if [ "$IPADDR" = dhcp ] ; then
  knetinfo="netcfg/get_hostname=$hname "
else
  # There's no good way to get a hostname here, but the postinstall will deal.
  # True, but thanks to wget, there's a bad way to get a hostname
  knetinfo="$nodhcp \
netcfg/get_domain=mit.edu \
netcfg/get_hostname=$hname \
netcfg/get_nameservers=\"18.72.0.3 18.70.0.160 18.71.0.151\" \
netcfg/get_ipaddress=$IPADDR \
netcfg/get_netmask=$NETMASK \
netcfg/get_gateway=$GATEWAY \
netcfg/confirm_static=true"
fi

# SIGH  See LP #818933
# This is fixed in Oneiric's kernel, but the PXE server is still serving
# natty (and will continue to do so until we have hardware that fails)
acpi=""
if [ "$(cat /sys/class/dmi/id/product_name)" = "OptiPlex 790" ]; then
    acpi="reboot=pci"
fi

kargs="$knetinfo $kbdcode $acpi locale=en_US interface=auto \
url=http://18.9.60.73/installer/$distro/debathena.preseed \
da/pxe=$pxetype da/i=$installertype da/m=$mirrorsite \
da/part=$partitioning --"

echo "Continuing in five seconds..."
if [ "$test" = "test" ]; then
    echo "Would run kexec with these args:"
    echo "$dkargs $kargs"
    exit 0
fi
if hash wc > /dev/null 2>&1; then
    if [ $(echo "$dkargs $kargs" | wc -c) -gt 512 ]; then
	echo "Kernel arguments exceed 512 bytes.  This will probably"
	echo "end badly.  If this install fails, be sure to mention"
	echo "this specific message in your bug report."
    fi
fi

debug "About to run kexec with these args: $dkargs $kargs"
./kexec -l linux --append="$dkargs $kargs" --initrd=initrd.gz \
	  && sleep 3 && chvt 1 && sleep 2 && ./kexec -e
curaddr="$(ip address show $ETH0 | grep inet | sed -e 's/^[ ]*inet //' | cut -d/ -f 1)"
echo "Secondary installed failed; please contact release-team@mit.edu"
echo "with the circumstances of your install attempt.  Here's a shell for debugging."
echo "You can type 'httpd' to start an HTTP server which will make"
echo "the system log available if you connect to http://$curaddr"
# We don't want to let this fall through to an actual install of whatever
# kernel we're using.
while : ; do /bin/sh ; done
exit 0
