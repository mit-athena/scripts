#!/bin/sh
DEBIAN_CODES="lenny squeeze hardy karmic lucid maverick natty"
gettag() {
    case "$1" in
	lenny)
	    echo "~debian5.0"
	    ;;
	squeeze)
	    echo "~debian6.0~0.3"
	    ;;
	hardy)
	    echo "~ubuntu8.04"
	    ;;
        karmic)
            echo "~ubuntu9.10"
            ;;
	lucid)
	    echo "~ubuntu10.04"
	    ;;
	maverick)
	    echo "~ubuntu10.10"
	    ;;
	natty)
	    echo "~ubuntu11.04~0.3"
	    ;;
	versions)
	    echo "$DEBIAN_CODES"
	    ;;
	*)
	    echo "error"
	    return 1
	    ;;
    esac
}
