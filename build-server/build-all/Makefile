suite := natty
psuite := maverick
STAMPS := /afs/sipb.mit.edu/project/debathena/machines/awesome-build-server/stamps.$(suite)

package = $(STAMPS)/$(1).done

all: build-all

deps.mk: gen-build-deps
	./gen-build-deps $(psuite) > $@
include deps.mk

build/%: $(call package,%)
	:

$(call package,%):
	file=$$(mktemp -t 'stupid.XXXXXX') && \
		echo "screen sh -c '$(CURDIR)/do-build $* $(STAMPS)/$* $(suite) $(psuite)'" > "$$file" && \
		echo "other" >> "$$file" && \
		screen -X source "$$file" && \
		sleep 2 && \
		rm -f "$$file"
	[ -e $(STAMPS)/$*.started ]
	while ! [ -e $(STAMPS)/$*.done ] && ! [ -e $(STAMPS)/$*.error ]; do sleep 1; done
	rm -f $(STAMPS)/$*.started
	rm -f $(STAMPS)/$*.error
	[ -e $(STAMPS)/$*.done ]

clean:
	rm -f deps.mk $(STAMPS)/*.started $(STAMPS)/*.error
