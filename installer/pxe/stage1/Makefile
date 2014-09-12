# This is pretty dangerous in a bunch of ways.  Approach with caution.
DESTDIR=/afs/athena.mit.edu/system/athena10/installer/stage1
SERVERIP=18.9.60.73
INSTALLER=stage1

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${DESTDIR} clean host kexec ${DESTDIR}/debathena.tar.gz

${DESTDIR}:
	$(error $(DESTDIR) does not exist)

kexec: kexec/kexec
	mkdir -p debathena/lib
	install -m 755 kexec/kexec debathena/lib

host: host.amd64 host.i386
	mkdir -p debathena/lib
	install -m 755 host.amd64 debathena/lib
	install -m 755 host.i386 debathena/lib

host.amd64: host/host.c
	gcc -m64 -static host/host.c -lcares -o $@

host.i386: host/host.c
	gcc -m32 -static host/host.c -lcares -o $@

debathena.preseed:
	@echo "d-i preseed/include_command string wget -q http://$(SERVERIP)/installer/$(INSTALLER)/debathena-loader.sh ; sh debathena-loader.sh" > $@

${DESTDIR}/debathena.tar.gz: debathena.preseed debathena-loader.sh debathena
	test -w "$(DESTDIR)"
	git rev-parse --short HEAD > debathena/version
	tar czvf ${DESTDIR}/debathena.tar.gz --exclude "*~" debathena
	cp debathena.preseed debathena-loader.sh ${DESTDIR}
	rm debathena/version
clean:
	rm -f host.amd64 host.i386
	rm -rf debathena/lib
	rm debathena.preseed

.PHONY: clean install host kexec debathena.preseed
