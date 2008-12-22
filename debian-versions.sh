#!/bin/sh
DEBIAN_CODES="etch lenny dapper gutsy hardy intrepid"
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
	gutsy)
	    echo "~ubuntu7.10"
	    ;;
	hardy)
	    echo "~ubuntu8.04"
	    ;;
	intrepid)
	    echo "~ubuntu8.10"
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
