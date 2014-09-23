#!/bin/sh

MACHINES="adjective-animal.mit.edu toy-story-character.mit.edu santa-cruz-operation.mit.edu"

b=""
betatxt=""
if [ "$1" = "beta" ]; then
  b="-b"
  betatxt="(using the beta installer)"
fi

notify() {
  if ! zwrite -q -d -c debathena -i tester \
    -s "Automated install test" -m "$@"; then
    echo "Couldn't send zephyr: $@" >&2
  fi
}

zcolor() {
  echo "@{@color($1) $2}"
}

test_machine() {
  HOSTNAME="$1"
  CLUSTER="$(getcluster -p -h "$HOSTNAME" $(lsb_release -sr) | awk '/^APT_RELEASE/ { print $2 }')"
  [ -z "$CLUSTER" ] && CLUSTER="(unknown apt_release)"
  LOGFILE="${HOME}/logs/$(uuidgen).log"
  if /home/tester/install-test.sh $b -h "$HOSTNAME" -l "$LOGFILE"; then
    notify "$(zcolor green Success:) $CLUSTER cluster machine ${betatxt}"
  else
    notify "$(zcolor red FAILED:) $CLUSTER cluster machine ${betatxt}
Logs can be found in $LOGFILE"
  fi
}

for m in $MACHINES; do
  test_machine "$m"
done

exit 0
