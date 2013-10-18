#!/bin/sh
DEBIAN_CODES="squeeze wheezy jessie lucid precise quantal raring saucy"
gettag() {
    case "$1" in
	squeeze)
	    echo "~debian6.0"
	    ;;
	wheezy)
	    echo "~debian7.0"
	    ;;
	jessie)
	    echo "~debian8.0~0.1"
	    ;;
	lucid)
	    echo "~ubuntu10.04"
	    ;;
	precise)
	    echo "~ubuntu12.04"
	    ;;
	quantal)
	    echo "~ubuntu12.10"
	    ;;
	raring)
	    echo "~ubuntu13.04"
	    ;;
	saucy)
	    echo "~ubuntu13.10"
	    ;;
	trusty)
	    echo "~ubuntu14.04~0.1"
	    ;;
	raspbian-wheezy)
	    echo "~raspbian7.0~0.1"
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
