#!/bin/sh
# Athena 10 placeholder install script.
# Maintainer: debathena@mit.edu
# Based on Debathena installer script by: Tim Abbott <tabbott@mit.edu>

# Download this to an Ubuntu machine and run it as root.  It can
# be downloaded with:
#   wget http://athena10.mit.edu/install-athena10.sh

set -e

output() {
  printf '\033[38m'; echo "$@"; printf '\033[0m'
}

error() {
  printf '\033[31m'; echo "$@"; printf '\033[0m'
  exit 1
}

ask() {
  answer=''
  while [ y != "$answer" -a n != "$answer" ]; do
    printf '\033[38m'; echo -n "$1"; printf '\033[0m'
    read answer
    [ Y = answer ] && answer=y
    [ N = answer ] && answer=n
    [ -z "$answer" ] && answer=$2
  done
  output ""
}

if [ `id -u` != "0" ]; then
  error "You must run the Athena 10 installer as root."
fi

echo "Welcome to the Athena 10 install script."
echo ""
echo "Please choose the category which bets suits your needs.  Each category"
echo "in this list includes the functionality of the previous ones.  See the"
echo "documentation at http://athena10.mit.edu for more information."
echo ""
echo "  standard:    Athena client software (e.g. discuss) and customizations"
echo "  login:       Allow Athena users to log into your machine"
echo "  workstation: Athena graphical login customizations"
echo ""

# Hack to deal with the older PXE installer (which used a simple flag file to
# indicate a PXE cluster install).
if test -f /root/unattended-cluster-install ; then
  echo cluster > /root/pxe-install-flag
fi

category=""
if test -f /root/pxe-install-flag ; then
  pxetype=`head -1 /root/pxe-install-flag`
  if [ cluster = "$pxetype" ] ; then
    category=cluster ; 
    echo "PXE cluster install detected, so installing \"cluster\"."
  fi
fi
while [ standard != "$category" -a login != "$category" -a \
        workstation != "$category" -a cluster != "$category" ]; do
  output -n "Please choose a category or press control-C to abort: "
  read category
done
mainpackage=debathena-$category

dev=no
echo
if [ cluster != $category ] ; then
  ask "Will this machine be used to build Debathena packages [y/N]? " n
  if [ y = "$answer" ]; then
    dev=yes
  fi
fi

csoft=no
tsoft=no
echo "The extra-software package installs a standard set of software"
echo "determined to be of interest to MIT users, such as LaTeX.  It is pretty"
echo "big (several gigabytes, possibly more)."
echo ""
if [ cluster = $category ] ; then
  echo "Cluster install detected, so installing extras."
  csoft=yes
  # Not setting tsoft=yes here; -cluster will pull it in anyway.
else
  ask "Do you want the extra-software package [y/N]? " n
  if [ y = "$answer" ]; then
    csoft=yes
  fi  
fi

echo "A summary of your choices:"
echo "  Category: $category"
echo "  Debian development package: $dev"
echo "  Extra-software package: $csoft"
echo "  Third-party software package: $tsoft"
echo ""
if [ "$pxetype" ] ; then
  # Setup for package installs in a chrooted immediately-postinstall environment.
  echo "Setting locale."
  export LANG
  . /etc/default/locale
  echo "LANG set to $LANG."
  echo "Mounting /proc."
  mount /proc 2> /dev/null || :
  # Clear toxic environment settings inherited from the installer.
  unset DEBCONF_REDIR
  unset DEBIAN_HAS_FRONTEND
  if [ cluster = "$pxetype" ] ; then
    # Network, LVM, and display config that's specific to PXE cluster installs.
    # If someone is installing -cluster on an already-installed machine, it's
    # assumed that this config has already happened and shouldn't be stomped on.

    # Preseed an answer to the java license query, which license was already accepted
    # at install time:
    echo "sun-java6-bin shared/accepted-sun-dlj-v1-1 boolean true" |debconf-set-selections

    # Configure network based on the preseed file settings, if present.
    if test -f /root/athena10.preseed ; then
      # Switch to canonical hostname.
      ohostname=`cat /etc/hostname`
      # Hack to avoid installing debconf-get for just this.
      ipaddr=`grep netcfg/get_ipaddress /root/athena10.preseed|sed -e 's/.* //'`
      netmask=`grep netcfg/get_netmask /root/athena10.preseed|sed -e 's/.* //'`
      gateway=`grep netcfg/get_gateway /root/athena10.preseed|sed -e 's/.* //'`

      hostname=`host $ipaddr | \
          sed 's#^.*domain name pointer \(.*\)$#\1#' | sed 's;\.*$;;' | \
          tr '[A-Z]' '[a-z]'`
      if echo $hostname|grep -q "not found" ; then
	hostname=""
	printf "\a"; sleep 1 ; printf "\a"; sleep 1 ;printf "\a"
	echo "The IP address you selected, $ipaddr, does not have an associated"
	echo "hostname.  Please confirm that you're using the correct address."
	while [ -z "$hostname" ] ; do
	  echo -n "Enter fully qualified hostname [no default]: "
	  read hostname
	done
      fi
      echo ${hostname%%.*} > /etc/hostname
      sed -e 's/\(127\.0\.1\.1[ 	]*\).*/\1'"$hostname ${hostname%%.*}/" < /etc/hosts > /etc/hosts.new
      mv -f /etc/hosts.new /etc/hosts
      if grep -q dhcp /etc/network/interfaces ; then
	sed -e s/dhcp/static/ < /etc/network/interfaces > /etc/network/interfaces.new
	echo "	address $ipaddr" >> /etc/network/interfaces.new
	echo "	netmask $netmask" >> /etc/network/interfaces.new
	echo "	gateway $gateway" >> /etc/network/interfaces.new
	mv -f /etc/network/interfaces.new /etc/network/interfaces
      fi
      hostname ${hostname%%.*}
    fi

    # Free up designated LVM overhead.
    lvremove -f /dev/athena10/keep_2 || :

    # This makes gx755s suck less.
    if lspci -n|grep -q 1002:94c1 && ! grep -q radeonhd /etc/X11/xorg.conf ; then
      DEBIAN_FRONTEND=noninteractive aptitude -y install xserver-xorg-video-radeonhd
      cat >> /etc/X11/xorg.conf <<EOF
Section "Device"
	Identifier "Configured Video Device"
	Driver "radeonhd"
EndSection
EOF
    fi
  fi
else
  output "Press return to begin or control-C to abort"
  read dummy
fi

output "Installing lsb-release to determine system type"
aptitude -y install lsb-release
distro=`lsb_release -cs`
case $distro in
etch|lenny)
  ;;
dapper|edgy|feisty|gutsy|hardy|intrepid)
  ubuntu=yes
  ;;
*)
  error "Your machine seems to not be running a current Debian/Ubuntu release."
  ;;
esac

output "Adding the Athena 10 repository to the apt sources"
echo "(This may cause the update manager to claim new upgrades are available."
echo "Ignore them until this script is complete.)"
if [ -d /etc/apt/sources.list.d ]; then
  sourceslist=/etc/apt/sources.list.d/debathena.list
else
  sourceslist=/etc/apt/sources.list
fi

if [ ! -e "$sourceslist" ] || ! grep -q debathena "$sourceslist"; then
  if [ -e "$sourceslist" ]; then
    echo "" >> $sourceslist
  fi
  echo "deb http://athena10.mit.edu/apt $distro debathena debathena-config debathena-system openafs" >> $sourceslist
  echo "deb-src http://athena10.mit.edu/apt $distro debathena debathena-config debathena-system openafs" >> $sourceslist
fi

if [ "$ubuntu" = "yes" ]; then
  output "Making sure the universe repository is enabled"
  sed -i 's,^# \(deb\(\-src\)* http://archive.ubuntu.com/ubuntu [[:alnum:]]* universe\)$,\1,' /etc/apt/sources.list
fi

output "Downloading the Debathena archive key"
if ! wget http://athena10.mit.edu/apt/athena10-archive.asc ; then
  echo "Download failed; terminating."
  exit 1
fi
echo "36e6d6a2c13443ec0e7361b742c7fa7843a56a0b  ./athena10-archive.asc" | \
  sha1sum -c
apt-key add athena10-archive.asc
rm ./athena10-archive.asc

apt-get update

modules_want=$(dpkg-query -W -f '${Source}\t${Package}\n' 'linux-image-*' | \
 sed -nre 's/^linux-(meta|latest[^\t]*)\tlinux-image-(.*)$/openafs-modules-\2/p')
modules=
for m in $modules_want; do
  aptitude show $m > /dev/null && modules="$modules $m"
done

if [ -z "$modules" ]; then
  error "An OpenAFS modules metapackage for your kernel is not available."
fi

output "Installing OpenAFS kernel metapackage"
apt-get -y install $modules

# Use the noninteractive frontend to install the main package.  This
# is so that AFS and Zephyr don't ask questions of the user which
# debathena packages will later stomp on anyway.
output "Installing main Athena 10 metapackage $mainpackage"

DEBIAN_FRONTEND=noninteractive aptitude -y install "$mainpackage"

# This package is relatively small so it's not as important, but allow
# critical questions to be asked.
if [ yes = "$dev" ]; then
  output "Installing debathena-build-depends"
  DEBIAN_PRIORITY=critical aptitude -y install debathena-build-depends
fi

# Use the default front end and allow questions to be asked; otherwise
# Java will fail to install since it has to present its license.
if [ yes = "$csoft" ]; then
  output "Installing debathena-extra-software"
  DEBIAN_PRIORITY=critical aptitude -y install debathena-extra-software
fi
if [ yes = "$tsoft" ]; then
  output "Installing debathena-thirdparty"
  DEBIAN_PRIORITY=critical aptitude -y install debathena-thirdparty
fi
