#!/bin/sh

# If you edit these releases and tags, please also update
# dabuildsys/config.py in build-system.git (checked out on the builder
# at ~/build-system).

DEBIAN_CODES="wheezy jessie stretch precise trusty xenial artful bionic"
gettag() {
    case "$1" in
	squeeze)
	    echo "~debian6.0"
	    ;;
	wheezy)
	    echo "~debian7.0"
	    ;;
	jessie)
	    echo "~debian8.0"
	    ;;
	stretch)
	    echo "~debian9.0~0.1"
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
	    echo "~ubuntu14.04"
	    ;;
	utopic)
	    echo "~ubuntu14.10"
	    ;;
	vivid)
	    echo "~ubuntu15.04~0.1"
	    ;;
	wily)
	    echo "~ubuntu15.10~0.1"
	    ;;
	xenial)
	    echo "~ubuntu16.04~0.1"
	    ;;
	yakkety)
	    echo "~ubuntu16.10~0.1"
	    ;;
	zesty)
	    echo "~ubuntu17.04~0.1"
	    ;;
	artful)
	    echo "~ubuntu17.10~0.1"
	    ;;
	bionic)
	    echo "~ubuntu18.04~0.1"
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
