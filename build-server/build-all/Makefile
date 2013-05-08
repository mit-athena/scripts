ifndef suite
$(error FATAL: 'suite' is not set (e.g. make suite=foo [psuite=bar] target))
endif
ifndef psuite
$(warning WARNING: 'psuite' is not defined.  Assuming a rebuild (psuite=$(suite)))
psuite:= $(suite)
endif

STAMPS := /afs/sipb.mit.edu/project/debathena/machines/awesome-build-server/stamps.$(suite)

package = $(STAMPS)/$(1).done

all: build-all

deps.mk: gen-build-deps
	./gen-build-deps $(psuite) > $@
include deps.mk

build/%: $(call package,%)
	:

$(call package,%):
	@echo "Starting build of $*"
	@if [ -e $(STAMPS)/$*.started ]; then echo "Error, remove 'started' stamp and try again."; false; fi
	@rm -f $(STAMPS)/$*.error
	@file=$$(mktemp -t 'stupid.XXXXXX') && \
		echo "screen sh -c '$(CURDIR)/do-build $* $(STAMPS)/$* $(suite) $(psuite)'" > "$$file" && \
		echo "other" >> "$$file" && \
		screen -X source "$$file" && \
		sleep 2 && \
		rm -f "$$file"
	@[ -e $(STAMPS)/$*.started ]
	@echo -n "Building $*..."
	@while ! [ -e $(STAMPS)/$*.done ] && ! [ -e $(STAMPS)/$*.error ]; do sleep 1; done
	@if [ -e $(STAMPS)/$*.done ]; then echo "OK"; else echo "FAILED"; fi
	@rm -f $(STAMPS)/$*.started
	@rm -f $(STAMPS)/$*.error
	@[ -e $(STAMPS)/$*.done ]

clean:
	rm -f deps.mk $(STAMPS)/*.started $(STAMPS)/*.error
