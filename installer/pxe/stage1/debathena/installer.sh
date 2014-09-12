#!/bin/sh
#
# The Debathena stage 1 installer.  This installer will:
# - configure networking
# - determine what metapackage to install, as well as some other advanced
#   installation options
# - download the stage2 initrd and kernel
# - kexec into them.

OWNER="install-debathena"
: ${PREFIX="/debathena"}
TEMPLATE_FILE="${PREFIX}/debathena.templates"
NETPARAMS="${PREFIX}/athena/netparams"
MASKS_FILE="${PREFIX}/athena/masks"
DEFAULT_DISTRO=trusty
NAMESERVERS="18.72.0.3 18.71.0.151 18.70.0.160"

# A URI which, if it can be reached, indicates the machine has
# a real connection to MITnet
NETWORK_TEST_URI="http://debathena.mit.edu/net-install"

# Net device to use (filled in later)
ETH0=

debug () {
  if [ -z "$DA_DEBUG" ]; then
    logger -t install.debug "$@"
  else
    echo "$DEBUG: $@" >&2
  fi
}

run () {
  if [ -n "$DA_DEBUG" ]; then
    echo "Command: $@"
  else
    "$@"
  fi
}

# Some Debconf helper functions to avoid having to
# type the owner each time

# Get the value of a question
get () {
  question="$1"
  db_get $OWNER/$question && echo "$RET"
}

# Ask a question with a priority (defaults to 'high')
# and a title (defaults to "Debathena Installer")
# Then call db_get, so the value is in RET
ask () {
  question="$1"
  priority="${2:-high}"
  db_fset $OWNER/$question seen false
  db_title "${3:-Debathena Installer}"
  db_input "$priority" $OWNER/$question
  if [ $? -ge 10 ] && [ $? -le 29 ]; then
    error "An internal error occurred while asking a question"
  fi
  db_go && db_get $OWNER/$question
}

# Thin wrapper around db_subst
swap () {
  question="$1"
  db_subst $OWNER/$question "$2" "$3"
}

# Attempt to run the netparams command.  If it succeeds,
# pre-seed the netmask and gateway values
guess_netparams() {
  local params
  params="$($NETPARAMS -f "$MASKS_FILE" "$IPADDR" 2>/dev/null)"
  if [ $? -eq 0 ]; then
    # netparams returns its output in this format:
    #    NETMASK NETWORK BROADCAST GATEWAY MASKBITS
    db_set $OWNER/netmask "$(echo "$params" | cut -d ' ' -f 1)"
    db_set $OWNER/gateway "$(echo "$params" | cut -d ' ' -f 4)"
    return 0
  else
    return 1
  fi
}

confirm_net() {
  swap confirm_net IPADDR "$(get ipaddr)"
  swap confirm_net HOSTNAME "$(get hostname)"
  swap confirm_net NETMASK "$(get netmask)"
  swap confirm_net GATEWAY "$(get gateway)"
  db_set $OWNER/confirm_net true
  ask confirm_net
}

error () {
  msg="${1:-The installation cannot continue.}"
  swap ohnoes errormsg "$msg"
  ask ohnoes critical
  while true; do
    echo "Please reboot now."
    read dummy
  done
}

# Ask a question, requiring the answer to be a valid IP
ask_valid_ip() {
  while true; do
    ask "$1"
    if ! dahost -i "$RET"; then
      ask invalid_ip critical
      continue
    fi
    break
  done
}

# Determine which interface to use
select_interface() {
  IFACES="$(ip -o link show | grep -v loopback | cut -d : -f 2 | tr -d ' ')"
  NUMIF="$(echo "$IFACES" | wc -l)"
  debug "Found $NUMIF interfaces: $IFACES"
  if [ "$NUMIF" -gt 1 ]; then
    # Do something clever here in the future
    ETH0="$(echo "$IFACES" | head -1)"
  elif [ "$NUMIF" -eq 1 ]; then
    ETH0="$IFACES"
  else
    return 1
  fi
  return 0
}

# Configure the network manually
manual_netconfig() {
  local IPADDR params
  while true; do
    ask_valid_ip ipaddr critical
    IPADDR="$RET"
    debug manual_netconfig IPADDR "$IPADDR"
    query_dns "$IPADDR"
    if [ $? -eq 0 ]; then
      db_set $OWNER/hostname "$DAHOSTNAME"
    fi
    ask hostname critical
    if ! echo "$RET" | grep -qi '[a-z]'; then
      ask invalid_hostname critical
      continue
    fi
    guess_netparams
    ask_valid_ip netmask
    ask_valid_ip gateway
    confirm_net
    [ "$RET" = "true" ] && break
  done
}

# Configure the network automagically, either from an IP
# or hostname.  If any step of this fails, fall back to manual config
auto_netconfig() {
  while true; do
    ask ip_or_hostname critical
    IP_OR_HOST="$RET"
    [ -n "$IP_OR_HOST" ] || continue
    query_dns "$IP_OR_HOST"
    case $? in
      0)
        break
        ;;
      128)
        if ! dahost -i "$IP_OR_HOST"; then
          db_reset "$OWNER/dns_not_found"
          ask dns_not_found
          [ "$RET" = "true" ] || return 1
        else
          # Pre-seed the value for manual config
          db_set $OWNER/ipaddr "$IP_OR_HOST"
          return 1
        fi
        ;;
      *)
        return 1
        ;;
    esac
  done
  IPADDR="$DAIPADDR"
  db_set $OWNER/ipaddr "$IPADDR"
  db_set $OWNER/hostname "$DAHOSTNAME"
  guess_netparams
}

# Look up something in DNS, with a debconf progress bar
query_dns() {
  db_progress START 0 2 $OWNER/please_wait
  db_progress STEP 1
  db_progress INFO $OWNER/querying_dns
  LOOKUP="$(dahost -s "$@")"
  rv=$?
  debug "query_dns" "rv=$rv" "LOOKUP=$LOOKUP"
  db_progress SET 2
  db_progress STOP
  if [ $rv -eq 0 ]; then
    eval "$LOOKUP"
  else
    DAIPADDR=
    DAHOSTNAME=
  fi
  debug "query_dns" "DAIPADDR=$DAIPADDR DAHOSTNAME=$DAHOSTNAME"
  unset LOOKUP
  return $rv
}

apply_netconfig() {
  IPADDR="$(get ipaddr)"
  NETMASK="$(get netmask)"
  GATEWAY="$(get gateway)"

  if [ -n "$IPADDR" ] && [ -n "$NETMASK" ] && [ -n "$GATEWAY" ]; then
    run killall dhclient
    run ip addr flush dev $ETH0
    run ip addr add $IPADDR/$NETMASK dev $ETH0
    run route delete default 2>/dev/null
    run route add default gw "$GATEWAY"
    rm -f $PREFIX/resolv.conf.tmp
    for ns in $NAMESERVERS; do
      echo "nameserver $ns" >> $PREFIX/resolv.conf.tmp
    done
    mv -f $PREFIX/resolv.conf.tmp /etc/resolv.conf
  fi
  unset IPADDR NETMASK GATEWAY
}

netconfig() {
  if ! auto_netconfig; then
    ask autonet_fail critical
    manual_netconfig
  else
    confirm_net
    [ "$RET" = "true" ] || manual_netconfig
  fi
}

test_uri() {
  local WGETARGS
  WGETARGS="--spider"
  if run wget --help 2>&1 | grep -q BusyBox; then
    WGETARGS="-s"
  fi
  # Test the mirror
  wget $WGETARGS "$1" 2>&1 > /dev/null
}

split_choices() {
  # Given a multi $RET value, split it into tab-separated
  # fields (suitable for the default IFS) and replace spaces
  # in question names with underscores.
  SPLIT="$(echo "$RET" | sed -e 's/, /\t/g; s/ /_/g;')"
}

advanced() {
  db_reset $OWNER/advanced
  db_metaget $OWNER/advanced Choices
  split_choices
  for choice in $SPLIT; do
    db_reset $OWNER/$choice
  done
  advanced_opts=
  ask advanced
  [ $? -eq 30 ] && return
  split_choices
  for adv in $SPLIT; do
    ask $adv
  done
}

config_network() {
  if [ "$(get use_dhcp)" = "true" ]; then
    # Hope for the best
    db_set $OWNER/hostname "$(hostname)"
  else
    netconfig
    apply_netconfig
  fi
}

config_installer() {
  db_set $OWNER/distribution "$DEFAULT_DISTRO"
  default_pkg="workstation"
  pkg_choices="standard, login, login-graphical, workstation"
  # You are not allowed to install -cluster with DHCP
  if [ "$(get use_dhcp)" != "true" ]; then
    default_pkg="cluster"
    pkg_choices="${pkg_choices}, cluster"
  fi
  swap metapackage meta_choices "$pkg_choices"
  db_set $OWNER/metapackage "$default_pkg"
  while true; do
    # Disable "backing up"
    db_capb ""
    ask metapackage
    # Enable "backing up"
    db_capb backup
    ask want_advanced
    [ $? -eq 30 ] && continue
    [ "$RET" = "true" ] && advanced
    metapackage=$(get metapackage)
    distro=$(get distribution)
    arch=$(get architecture)
    installer=production
    mirror=$(get mirror)
    [ "$(get beta_installer)" = "true" ] && installer=beta
    partitioning=auto
    [ "$(get manual_partitioning)" = "true" ] && partitioning=manual
    stage2_debug=0
    debugtxt=
    if [ "$(get debug_mode)" = "true" ]; then
      stage2_debug=1
      debugtxt="Stage 2 debugging enabled."
    fi
    extra_kargs="$(get kernel_arguments)"
    swap confirm_install metapackage "$metapackage"
    swap confirm_install distro "$distro"
    swap confirm_install arch "$arch"
    swap confirm_install installer "$installer"
    swap confirm_install partitioning "$partitioning"
    swap confirm_install mirror "$mirror"
    swap confirm_install extra_kargs "$extra_kargs"
    swap confirm_install debugtxt "$debugtxt"
    db_set $OWNER/confirm_install true
    ask confirm_install
    [ "$RET" = "true" ] && break
  done
  # Turn off back up, since it's pointless now.
  db_capb ""
  if [ "$partitioning" = "auto" ]; then
    ask destroys
  fi
}

# Begin main installer code

# Load debconf
. /usr/share/debconf/confmodule

# Unclear if needed, since we're talking to an existing
# frontend already?
db_version 2.0

# Load our template file
db_x_loadtemplatefile $TEMPLATE_FILE $OWNER
# in cdebconf (in d-i), this returns 0 even if loading fails,
# because of course it does
if [ $? -ne 0 ]; then
  echo "Failed to load templates!" >&2
  exit 1
fi

arch=unknown
# If archdetect exists (in d-i) it returns, e.g. amd64/generic
if hash archdetect > /dev/null 2>&1; then
  arch="$(archdetect | cut -d / -f 1)"
else
  case "$(uname -m)" in
    x86_64)
      arch=amd64;;
    i[3-6]86)
      arch=i386;;
  esac
fi
if ! [ -x "$PREFIX/lib/host.$arch" ]; then
  error "The installer was unable to locate its DNS helper."
else
  ln -s "$PREFIX/lib/host.$arch" "$PREFIX/lib/dahost"
fi
if ! [ -x "$PREFIX/lib/kexec" ]; then
  error "The installer was unable to locate kexec."
fi
export PATH="$PREFIX/lib:$PATH"

if ! select_interface; then
  error "Could not find an Ethernet interface to use."
fi

if test_uri "$NETWORK_TEST_URI"; then
  ask use_dhcp critical
fi

# TODO: Once apply_netconfig is idempotent, wrap this in a loop, and
# allow the user to back up and try again if the mirror can't be contacted.
config_network
config_installer

if ! test_uri "http://$mirror/ubuntu"; then
  error "Cannot contact mirror: $mirror"
fi

nodhcp="netcfg/disable_autoconfig=true"
kbdcode="keyboard-configuration/layoutcode=us"

#netcfg arguments
if [ "$(get use_dhcp)" = "true" ]; then
  netcfg="netcfg/get_hostname=$(get hostname)"
else
  netcfg="$nodhcp netcfg/get_domain=mit.edu netcfg/get_hostname=$(get hostname) \
netcfg/get_nameservers=\"$NAMESERVERS\" \
netcfg/get_ipaddress=$(get ipaddr) netcfg/get_netmask=$(get netmask) \
netcfg/get_gateway=$(get gateway) netcfg/confirm_static=true"
fi

# TODO: Pass the actual interface we're using, not "auto", once we figure out
#       all the BOOTIF implications
kargs="$netcfg $kbdcode locale=en_US interface=auto \
url=http://18.9.60.73/installer/$distro/debathena.preseed \
da/pxe=$metapackage da/i=$installer da/m=$mirror \
da/part=$partitioning da/dbg=$stage2_debug $extra_kargs"

# Download the stage 2 components
# Why don't we just fetch these from the mirror, you ask?  Excellent
# question.  With the HWE stacks, there is no deterministic way to say
# "Give me the latest 12.04 installer".  You have to "know" that
# 12.04.2 is quantal, 12.04.4 is saucy, etc.  So we'll continue to
# use /net-install for now, because we can't have nice things.
db_progress START 0 4 $OWNER/please_wait
db_progress STEP 1
swap downloading thing "stage 2 kernel"
db_progress INFO $OWNER/downloading
run rm -rf "$PREFIX/stage2"
run mkdir "$PREFIX/stage2"
run wget -q -P "$PREFIX/stage2" "http://debathena.mit.edu/net-install/$distro/$arch/linux"
db_progress STEP 2
swap downloading thing "stage 2 initrd"
db_progress INFO $OWNER/downloading
run wget -q -P "$PREFIX/stage2" "http://debathena.mit.edu/net-install/$distro/$arch/initrd.gz"
db_progress STEP 3
run kexec -l "$PREFIX/stage2/linux" --append="$kargs" --initrd="$PREFIX/stage2/initrd.gz"
db_progress STEP 4
db_progress STOP
run kexec -e

# If we got here, something above failed.
error "The installer failed to load stage 2 of the installation."

# This should never fall through, but...
while true; do
  echo "Fatal error."
  read dummy
done
