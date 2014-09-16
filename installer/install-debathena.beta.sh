#!/bin/sh
# Athena installer script.
# Maintainer: debathena@mit.edu
# Based on original Debathena installer script by: Tim Abbott <tabbott@mit.edu>

# Download this to a Debian or Ubuntu machine and run it as root.  It can
# be downloaded with:
#   wget -N http://debathena.mit.edu/install-debathena.sh

set -e

# The user's umask will sometimes carry over; don't let that happen.
umask 022

output() {
  printf '\033[38m'; echo "$@"; printf '\033[0m'
}

error() {
  printf '\033[31m'; echo "$@"; printf '\033[0m'
}

ask() {
  answer=''
  while [ y != "$answer" -a n != "$answer" ]; do
    printf '\033[38m'; echo -n "$1"; printf '\033[0m'
    read answer
    [ Y = "$answer" ] && answer=y
    [ N = "$answer" ] && answer=n
    [ -z "$answer" ] && answer=$2
  done
  output ""
}

if [ `id -u` != "0" ]; then
  error "You must run the Debathena installer as root."
  if [ -x /usr/bin/sudo ]; then
    error "Try running 'sudo $0'."
  fi
  exit 1
fi

unattended=no
category=""

# Legacy code (to be replaced with debconf at some point)
if test -f /root/pxe-install-flag ; then
  category="$(head -1 /root/pxe-install-flag)"
  unattended=yes
  echo "PXE cluster install detected, so installing \"$category\"."
  # Remove the pxe install flag
  rm -f /root/pxe-install-flag
fi

have_lsbrelease="$(dpkg-query -W -f '${Status}' lsb-release 2>/dev/null)"
if [ "$have_lsbrelease" != "install ok installed" ]; then
  echo "The installer requires the 'lsb-release' package to determine"
  echo "whether or not installation can proceed."
  ask "Is it ok to install this package now? [Y/n] " y
  if [ y = "$answer" ]; then
    if ! apt-get -qq update && apt-get -qqy install lsb-release; then
	error "Could not install lsb-release.  Try installing it manually."
	exit 1
    fi
  else
    error "Sorry, lsb-release is required.  Cannot continue."
    exit 1
  fi
fi
distro=`lsb_release -cs`
aptitude=aptitude
prerelease=no
add_apt_repo=python-software-properties
case $distro in
  squeeze|wheezy)
    ;;
  jessie)
    prerelease=yes
    ;;
  utopic)
    prerelease=yes
    ubuntu=yes
    aptitude=apt-get
    ;;
  precise|saucy)
    ubuntu=yes
    aptitude=apt-get
    ;;
  trusty)
    ubuntu=yes
    aptitude=apt-get
    add_apt_repo=software-properties-common
    ;;
  lenny|hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|quantal|raring)
    error "The release you are running ($distro) is no longer supported."
    error "Generally, Debathena de-supports releases when they are no longer"
    error "supported by upstream.  If you believe you received this message"
    error "in error, please contact debathena@mit.edu."
    exit 1
    ;;
  *)
    error "Unsupported release codename: $distro"
    error "Sorry, Debathena does not support installation on this release at this time."
    error "(New releases may not be supported immediately after their release)."
    error "If you believe you are running a supported release or have questions,"
    error "please contact debathena@mit.edu"
    exit 1
    ;;
esac

if [ "$prerelease" = "yes" ]; then
    output "The release you are running ($distro) is not yet supported"
    output "and installing Debathena on it is probably a bad idea,"
    output "particularly for any purpose other than beta testing."
    output ""
    output "(New releases are generally supported a couple of weeks"
    output "after the official release date.  We strongly encourage you"
    output "to check http://debathena.mit.edu for support information"
    output "and try again later, or install the previous version of"
    output "the operating system.)"
    if [ "$unattended" != "yes" ]; then
	ask "Are you sure you want to proceed? [y/N] " n
	[ y != "$answer" ] && exit 1
    fi
fi

laptop=no
wifi=no
if [ -x /usr/sbin/laptop-detect ] && /usr/sbin/laptop-detect 2>/dev/null; then
    laptop=yes
fi

if [ -x /usr/bin/nmcli ] && /usr/bin/nmcli dev status 2>/dev/null | awk '{print $2}' | grep -q 802-11-wireless; then
    wifi=yes
fi

echo "Welcome to the Debathena installer."
echo ""
echo "Please choose the category which best suits your needs.  Each category"
echo "in this list includes the functionality of the previous ones.  See the"
echo "documentation at http://debathena.mit.edu for more information."
echo ""
echo "  standard:        Athena client software and customizations"
echo "                   Recommended for laptops and single-user computers."
echo "  login:           Allow Athena accounts to log into your machine"
echo "                   Recommended for private remote-access servers."
echo "  login-graphical: Athena graphical login customizations"
echo "                   Recommended for private multi-user desktops."
echo "  workstation:     Graphical workstation with automatic updates"
echo "                   Recommended for auto-managed cluster-like systems."
echo ""

if [ "$laptop" = "yes" ] || [ "$wifi" = "yes" ]; then
    cat <<EOF 
This machine appears to be a laptop or has at least one wireless
network device.  You probably want to choose "standard" unless this
device will have an uninterrupted network connection.
EOF
fi

while [ standard != "$category" -a login != "$category" -a \
        login-graphical != "$category" -a workstation != "$category" -a \
        cluster != "$category" ]; do
  output -n "Please choose a category or press control-C to abort: "
  read category
done

# We need noninteractive for PXE installs because you're not supposed
# to be interactive in a late_command, and nothing works (like
# debconf, for example).  Until #702 is fixed.
if [ "$unattended" = "yes" ]; then
  export DEBCONF_NONINTERACTIVE_SEEN=true
  export DEBIAN_FRONTEND=noninteractive
fi

mainpackage=debathena-$category

csoft=no
tsoft=no
resolvconfhack=no

case "$category" in
  cluster)
    msmtpmta=yes
    ;;
  workstation)
    msmtpmta=yes
    maildefault=y
    mailprompt="[Y/n]"
    ;;
  *)
    msmtpmta=no
    maildefault=n
    mailprompt="[y/N]"
    ;;
esac

if [ "$unattended" != "yes" ]; then
  echo "Debathena provides the 'debathena-msmtp-mta' package, which includes"
  echo "a wrapper for the 'sendmail' command that configures it to use the"
  echo "MIT outgoing servers and Kerberos authentication."
  echo "Advanced users may wish to skip this package and configure their own"
  echo "mail transport agent (e.g. Postfix) instead."
  echo
  ask "Install debathena-msmtp-mta? $mailprompt" $maildefault
  if [ y = "$answer" ]; then
    msmtpmta=yes
  fi
fi

echo "The extra-software package installs a standard set of software"
echo "determined to be of interest to MIT users, such as LaTeX.  It is pretty"
echo "big (several gigabytes, possibly more)."
echo ""
echo "Note: This package may include software with additional license terms."
echo "      By installing it, you are agreeing to the terms of these licenses."
echo "      For more information, please see http://debathena.mit.edu/licensing"
echo ""
if [ cluster = $category -o workstation = $category ] ; then
  # See Trac #648 and LP:471975
  resolvconfhack=yes
  echo "The extra-software package is required for '$category' and will be installed."
  csoft=yes
  # Not setting tsoft=yes here; -cluster will pull it in anyway.
else
  ask "Do you want the extra-software package [y/N]? " n
  if [ y = "$answer" ]; then
    csoft=yes
  fi
fi
if [ yes = "$csoft" ]; then
    # Preseed an answer to the java license query, which license was already accepted
    # at install time:
    echo "sun-java6-bin shared/accepted-sun-dlj-v1-1 boolean true" |debconf-set-selections
fi

if [ "$(cat /sys/class/dmi/id/product_name)" = "OptiPlex 790" ] && \
    dpkg --compare-versions "$(uname -r)" lt 3.2~; then
    noacpi=y
    if [ "$category" != "cluster" ]; then
	echo
	echo "The Dell 790 sometimes has problems rebooting.  The best way to"
	echo "work around this is to pass 'reboot=pci' at boot time."
	echo "This change will be made in your GRUB (bootloader) configuration."
	ask "Is it ok to do this now? [Y/n] " y
	if [ y != "$answer" ]; then
	    noacpi=n
	fi
    fi
    if [ "$noacpi" = "y" ] && ! grep -q "Added by install-debathena.sh to address reboot issues on the Dell 790" /etc/default/grub; then
	cat >> /etc/default/grub << 'EOF'

# Added by install-debathena.sh to address reboot issues on the Dell 790
GRUB_CMDLINE_LINUX="reboot=pci $GRUB_CMDLINE_LINUX"
EOF
	update-grub
    fi
fi

echo "A summary of your choices:"
echo "  Category: $category"
echo "  msmtp-mta: $msmtpmta"
echo "  Extra-software package: $csoft"
echo "  Third-party software package: $tsoft"
echo ""
if [ "$unattended" = "yes" ] && [ "$category" = "cluster" ]; then
  if wget -q http://athena10.mit.edu/installer/installing.txt; then
     cat installing.txt > /dev/tty6
     date > /dev/tty6
     chvt 6
     rm installing.txt
  fi
  # Divert the default background and install our own so that failed machines
  # are more conspicuous
  echo "Diverting default background..."
  bgimage=/usr/share/backgrounds/warty-final-ubuntu.png
  divertedbg=no
  if dpkg-divert --divert ${bgimage}.debathena --rename $bgimage; then
      divertedbg=yes
      if ! wget -N -O $bgimage http://debathena.mit.edu/error-background.png; then
	  echo "Hrm, that didn't work.  Oh well..."
	  dpkg-divert --rename --remove $bgimage
	  divertedbg=no
      fi
  fi
fi

if [ "$unattended" = "yes" ]; then
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
  if [ cluster = "$category" ] && [ "$unattended" = "yes" ]; then
    # Network, LVM, and display config that's specific to PXE cluster installs.
    # If someone is installing -cluster on an already-installed machine, it's
    # assumed that this config has already happened and shouldn't be stomped on.

    # Configure network based on the preseed file settings, if present.
    if test -f /root/debathena.preseed && ! grep -q netcfg/get_ipaddress /proc/cmdline; then
      # Switch to canonical hostname.
      ohostname=`cat /etc/hostname`
      # Hack to avoid installing debconf-get for just this.
      ipaddr=`grep netcfg/get_ipaddress /root/debathena.preseed|sed -e 's/.* //'`
      netmask=`grep netcfg/get_netmask /root/debathena.preseed|sed -e 's/.* //'`
      gateway=`grep netcfg/get_gateway /root/debathena.preseed|sed -e 's/.* //'`

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
	echo "	dns-nameservers 18.72.0.3 18.70.0.160 18.71.0.151" >> /etc/network/interfaces.new
	mv -f /etc/network/interfaces.new /etc/network/interfaces
      fi
      hostname ${hostname%%.*}
    fi

  fi
else
  output "Press return to begin or control-C to abort"
  read dummy
fi

# Set the "seen" flag for all debconf questions that we configure
# cluster is still non-interactive, see above.
# Except you can't set the "seen" flag for something that isn't installed
# so also set some sane defaults
cat <<EOF | debconf-set-selections
# Set sane defaults
postfix	postfix/main_mailer_type	select	Internet Site
openafs-client  openafs-client/thiscell string grand.central.org
openafs-client  openafs-client/cachesize string 150000
cyrus-common	cyrus-common/removespools	boolean	false
# A null value is fine as of krb5 1.6.dfsg.3-1
krb5-config     krb5-config/default_realm string 
# No value means use Hesiod
zephyr-clients  zephyr-clients/servers string
# These are also questions asked by default, but 
# the user should probably see them anyway.
#gdm     shared/default-x-display-manager seen true
#hddtemp hddtemp/daemon seen true
EOF

apt-get update

output "Verifying machine is up to date..."
pattern='^0 upgraded, 0 newly installed, 0 to remove'
if ! apt-get --simulate --assume-yes dist-upgrade | grep -q "$pattern"; then
    if [ "$unattended" = "yes" ] ; then
	output "Forcing an upgrade"
	apt-get --assume-yes dist-upgrade
    else 
	error "Your system is not up to date.  Proceeding with an install at"
	error "this time could render your system unusable."
	error "Please run 'apt-get dist-upgrade' as root or use the GUI update"
	error "manager to ensure your system is up to date before continuing."
	error "NOTE: You do NOT need to upgrade to a newer release of Ubuntu",
	error "you merely need to ensure you have the latest software updates"
	error "for the current version."
	exit 1
    fi
fi

if ! hash aptitude >/dev/null 2>&1; then
  output "Installing Debathena installer dependency: aptitude"
  apt-get -y install aptitude
fi

output "Installing Debathena installer dependencies: wget and dnsutils"
apt-get -y install wget dnsutils
if [ yes = "$resolvconfhack" ]; then
  output "Installing resolvconf ahead of time"
  apt-get -y install resolvconf
fi

if ! hash add-apt-repository >/dev/null 2>&1; then
    output "Installing add-apt-repository"
    apt-get -y install "$add_apt_repo"
fi

# Only add our openafs component if DKMS isn't available
openafs_component=""
if aptitude show openafs-modules-dkms > /dev/null; then
  modules="openafs-modules-dkms"
else
  openafs_component=" openafs"
fi

if [ "$modules" = "openafs-modules-dkms" ] && \
    [ "$ubuntu" = "yes" ]; then
    ppa="yes"
    output "OpenAFS is available from both the Ubuntu 'universe' repository"
    output "and a PPA (personal package archive) maintained by the OpenAFS"
    output "team.  We recommend using the PPA, as it is mostly likely to"
    output "keep pace with Ubuntu's kernel updates.  For some releases,"
    output "the PPA is required for AFS to function correctly at all."
    if [ "$unattended" != "yes" ]; then
	ask "Is that ok? [Y/n] " y
	if [ y != "$answer" ]; then
	    ppa="no"
	fi
    fi
    if [ "$ppa" = "yes" ]; then
	output "Enabling OpenAFS PPA..."
	add-apt-repository -y ppa:openafs/stable
    fi
fi

# Select the correct headers package
kernel_hdr_meta_pkgs=
if [ "$ubuntu" = "yes" ]; then
    # Ubuntu kernel metapackages have a source of 'linux-meta'
    # Find all of them and replace "-image-" with "-headers-".
    # Except the source _starts with_ linux-meta because of HWE
    # stacks (e.g. linux-meta-lts-quantal.  I hate you all.
    kernel_hdr_meta_pkgs=$(dpkg-query -W -f '${Source}\t${Package}\n' 'linux-image-*' | awk '$1 ~ /^linux-meta/ { sub(/-image-/, "-headers-", $2); print $2 }')
else
    # Debian.  "Yay".  Old squeeze has linux-latest-2.6 as the
    # metapackage.  squeeze-backpors and newer have linux-latest as
    # the metpackage.  For bonus points, wheezy can have two packages
    # installed with linux-latest as the metapackage, because one of
    # those is itself a metapckage.
    kernel_hdr_meta_pkgs=$(dpkg-query -W -f '${Source}::${Package}\n' 'linux-image-*' | awk -F:: '$1~/^linux-latest/ { sub(/-image-/, "-headers-", $2); print $2 }')
fi
pkgs_to_install=
for p in $kernel_hdr_meta_pkgs; do
    # Only install real packages
    if apt-cache show $p | grep -q '^Source: '; then
	pkgs_to_install=" $p"
    fi
done
if [ -z "$pkgs_to_install" ]; then
    output "We cannot find a kernel header metapackage for your kernel."
    output "You will need one in order for DKMS to build the openafs"
    output "kernel module.  You should probably stop here and figure out"
    output "what kernel metapackage you're running, and install the"
    output "corresponding kernel headers package."
    ask "Do you want to continue anyway? [y/N] " n
    if [ y != "$answer" ]; then
	exit 0
    fi
else
    output "Installing header packages: $pkgs_to_install"
    apt-get -y install $pkgs_to_install
fi

output "Adding the Debathena repository to the apt sources"
output "(This may cause the update manager to claim new upgrades are available."
output "Ignore them until this script is complete.)"
sourceslist=/etc/apt/sources.list.d/debathena.list
clustersourceslist=/etc/apt/sources.list.d/debathena.clusterinfo.list
if [ -z "$hostname" ] ; then hostname=`hostname` ; fi

if [ ! -e "$sourceslist" ] || ! grep -v ^# "$sourceslist" | grep -q debathena; then
  if [ -e "$sourceslist" ]; then
    echo "" >> $sourceslist
  fi
  echo "deb http://debathena.mit.edu/apt $distro debathena debathena-config debathena-system$openafs_component" >> $sourceslist
  echo "deb-src http://debathena.mit.edu/apt $distro debathena debathena-config debathena-system$openafs_component" >> $sourceslist
fi

# As of 6 March 2013, Hesiod no longer contains multiple unversioned 
# apt_release tokens (Trac: #1036).  development implies proposed.
# bleeding implies development, and the transitive property applies.
# It's possible we should have this be configurable via a URL
# rather than hardcoded.
apt_release=$(dig +short +bufsize=2048 ${hostname}.cluster.ns.athena.mit.edu TXT | tr -d '"' | awk '$1=="apt_release" { print $2 }')

if [ -n "$apt_release" ]; then
  extra_repos=
  case "$apt_release" in
    development)
      extra_repos="development proposed" ;;
    proposed)
      extra_repos="proposed" ;;
    bleeding)
      extra_repos="bleeding development proposed" ;;
    *)
      output "NOTE: Ignoring unknown apt_release value: \"$apt_release\"" ;;
  esac
  aptexplained=false
  for hc in $extra_repos; do
    echo "Adding $distro-$hc apt repository."
    if [ "${aptexplained}" = false ] ; then
      echo "" >> $clustersourceslist
      echo "# This file is automatically updated by debathena-auto-update" >> $clustersourceslist
      echo "# based on your Hesiod cluster information. If you want to" >> $clustersourceslist
      echo "# make changes, do so in another file." >> $clustersourceslist
      aptexplained=true
    fi
    echo "" >> $clustersourceslist
    echo "deb http://debathena.mit.edu/apt $distro-${hc} debathena debathena-config debathena-system$openafs_component" >> $clustersourceslist
    echo "deb-src http://debathena.mit.edu/apt $distro-${hc} debathena debathena-config debathena-system$openafs_component" >> $clustersourceslist
  done
fi

if [ "$ubuntu" = "yes" ]; then
  output "Making sure the universe repository is enabled"
  sed -i 's,^# \(deb\(\-src\)* http://archive.ubuntu.com/ubuntu [[:alnum:]]* universe\)$,\1,' /etc/apt/sources.list
fi

output "Downloading the Debathena archive signing key"
if ! wget -N http://debathena.mit.edu/apt/debathena-archive-keyring.asc ; then
  error "Download failed; terminating."
  exit 1
fi
echo "fa787714d1ea439c28458aab64962f755e2bdee7a3520919a72b641458757fa3586fd269cc1dae8d99047e00b3df88db0826f0c99a1f5a8771618b3c0be8e3bd  ./debathena-archive-keyring.asc" | \
  sha512sum -c
apt-key add debathena-archive-keyring.asc
rm ./debathena-archive-keyring.asc

$aptitude update

if [ -z "$modules" ]; then
  modules_want=$(dpkg-query -W -f '${Source}\t${Package}\n' 'linux-image-*' | \
   sed -nre 's/^linux-(meta|latest[^\t]*)\tlinux-image-(.*)$/openafs-modules-\2/p')
  modules=
  for m in $modules_want; do
    aptitude show $m > /dev/null && modules="$modules $m"
  done
fi

if [ -z "$modules" ]; then
  error "An OpenAFS modules metapackage for your kernel is not available."
  error "Please use the manual installation instructions at"
  error "http://debathena.mit.edu/install"
  error "You will need to compile your own AFS modules as described at:"
  error "http://debathena.mit.edu/troubleshooting#openafs-custom"
  exit 1
fi

output "Installing OpenAFS kernel metapackage"
apt-get -y install $modules

if [ "cluster" = "$category" ] || [ "workstation" = "$category" ] ; then
    output "Installing debathena-license-config"
    apt-get -y install debathena-license-config
fi

# Use the noninteractive frontend to install the main package.  This
# is so that AFS and Zephyr don't ask questions of the user which
# debathena packages will later stomp on anyway.
output "Installing main Debathena metapackage $mainpackage"

$aptitude -y install "$mainpackage"

# Use the default front end and allow questions to be asked; otherwise
# Java will fail to install since it has to present its license.
if [ yes = "$csoft" ]; then
  output "Installing debathena-extra-software"
  DEBIAN_PRIORITY=critical $aptitude -y install debathena-extra-software
fi
if [ yes = "$tsoft" ]; then
  output "Installing debathena-thirdparty"
  DEBIAN_PRIORITY=critical $aptitude -y install debathena-thirdparty
fi

if [ yes = "$msmtpmta" ]; then
  output "Installing debathena-msmtp-mta"
  DEBIAN_PRIORITY=critical $aptitude -y install debathena-msmtp-mta
fi

# Post-install cleanup for cluster systems.
if [ "$divertedbg" = "yes" ]; then
    rm -f $bgimage
    if ! dpkg-divert --rename --remove $bgimage; then
	echo "Failed to remove diversion of background.  You probably don't care."
    fi
fi

if [ cluster = "$category" ] ; then
  if hash apt-file >/dev/null 2>&1; then
    output "Updating the apt-file cache..."
    apt-file update
  fi
  # Force an /etc/adjtime entry so there's no confusion about whether the
  # hardware clock is UTC or local.
  echo "Setting hardware clock to UTC."
  hwclock --systohc --utc
fi
