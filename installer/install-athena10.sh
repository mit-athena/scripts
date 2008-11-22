#!/bin/sh
# Athena 10 placeholder install script.
# Maintainer: Greg Hudson <ghudson@mit.edu>
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

category=""
while [ standard != "$category" -a login != "$category" -a \
        workstation != "$category" ]; do
  output -n "Please choose a category or press control-C to abort: "
  read category
done
mainpackage=debathena-$category

dev=no
echo
ask "Will this machine be used to build Debathena packages [y/N]? " n
if [ y = "$answer" ]; then
  dev=yes
fi

csoft=no
echo "The extra-software package installs a standard set of software"
echo "determined to be of interest to MIT users, such as LaTeX.  It is pretty"
echo "big (several gigabytes, possibly more)."
echo ""
ask "Do you want the extra-software package [y/N]? " n
if [ y = "$answer" ]; then
  csoft=yes
fi

echo "A summary of your choices:"
echo "  Category: $category"
echo "  Debian development package: $dev"
echo "  Extra-software package: $csoft"
echo ""
output "Press return to begin or control-C to abort"
read dummy

output "Installing lsb-release to determine system type"
aptitude -y install lsb-release
distro=`lsb_release -cs`
case $distro in
etch|lenny)
  ;;
dapper|edgy|feisty|gutsy|hardy)
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
