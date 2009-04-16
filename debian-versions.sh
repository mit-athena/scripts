#!/bin/sh
DEBIAN_CODES="etch lenny squeeze dapper gutsy hardy intrepid jaunty"
gettag() {
    case "$1" in
	etch)
	    echo "~debian4.0"
	    ;;
	lenny)
	    echo "~debian5.0"
	    ;;
	squeeze)
	    echo "~debian6.0~0.1"
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
	jaunty)
	    echo "~ubuntu9.04~0.1"
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
