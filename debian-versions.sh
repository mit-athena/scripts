#!/bin/sh
DEBIAN_CODES="squeeze hardy lucid natty oneiric"
gettag() {
    case "$1" in
	squeeze)
	    echo "~debian6.0~0.3"
	    ;;
	wheezy)
	    echo "~debian7.0~0.1"
	    ;;
	hardy)
	    echo "~ubuntu8.04"
	    ;;
	lucid)
	    echo "~ubuntu10.04"
	    ;;
	natty)
	    echo "~ubuntu11.04"
	    ;;
	oneiric)
	    echo "~ubuntu11.10"
	    ;;
	precise)
	    echo "~ubuntu12.04"
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
