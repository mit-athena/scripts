#!/bin/sh
DEBIAN_CODES="squeeze wheezy lucid precise quantal raring"
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
	    echo "~ubuntu13.10~0.1"
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
