#!/bin/sh
DEBIAN_CODES="etch lenny dapper edgy feisty gutsy hardy"
gettag() {
    case "$1" in
	etch)
	    echo "~debian4.0"
	    ;;
	lenny)
	    echo "~debian4.1~0.1"
	    ;;
	dapper)
	    echo "~ubuntu6.06"
	    ;;
	edgy)
	    echo "~ubuntu6.10"
	    ;;
	feisty)
	    echo "~ubuntu7.04"
	    ;;
	gutsy)
	    echo "~ubuntu7.10"
	    ;;
	hardy)
	    echo "~ubuntu8.04"
	    ;;
	versions)
	    echo "$DEBIAN_CODES"
	    exit 1
	    ;;
	*)
	    echo "error"
	    exit 1
	    ;;
    esac
}
