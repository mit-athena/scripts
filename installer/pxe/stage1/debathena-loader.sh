#!/bin/sh

# To minimize the number of places we hardcode things, we use the
# preseed URL to figure out where to get the tarball from.
# This will break if the .preseed and tarball are not in the same
# location.  "Don't do that."

URI="$(debconf-get preseed/url | sed -e 's/debathena\.preseed$/debathena.tar.gz/')"

if [ -n "$URI" ]; then
    cd /
    wget "$URI" > /dev/tty5 2>&1
    tar xzf debathena.tar.gz > /dev/tty5 2>&1
    [ -x /debathena/installer.sh ] && exec /debathena/installer.sh
else
    echo "Error: failed to retrieve preseed/url from debconf" > /dev/tty5
fi
chvt 5
cat <<EOF > /dev/tty5
************************************************************************
* If you are seeing this message, something went wrong.
* Contact release-team@mit.edu and report this error message, as well as
* any error messages you may see above this line.

* You can reboot your computer now.  No changes were made to your
* computer.
************************************************************************
EOF
while true; do
    sh < /dev/tty5 > /dev/tty5 2>&1
done

