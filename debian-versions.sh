#!/bin/sh
DEBIAN_CODES="squeeze wheezy hardy lucid natty oneiric precise"
gettag() {
    case "$1" in
	squeeze)
	    echo "~debian6.0"
	    ;;
	wheezy)
	    echo "~debian7.0~0.3"
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
