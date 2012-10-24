#!/bin/sh
DEBIAN_CODES="squeeze wheezy lucid oneiric precise quantal"
gettag() {
    case "$1" in
	squeeze)
	    echo "~debian6.0"
	    ;;
	wheezy)
	    echo "~debian7.0~0.4"
	    ;;
	hardy)
	    # Remove this at the end of April 2013
	    echo "~ubuntu8.04"
	    ;;
	lucid)
	    echo "~ubuntu10.04"
	    ;;
	oneiric)
	    echo "~ubuntu11.10"
	    ;;
	precise)
	    echo "~ubuntu12.04"
	    ;;
	quantal)
	    echo "~ubuntu12.10~0.1"
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
