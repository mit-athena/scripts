# This is pretty dangerous in a bunch of ways.  Approach with caution.
d=/afs/athena.mit.edu/system/athena10/installer/stage1

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${d}/debathena.tar.gz

${d}/debathena.tar.gz: debathena.preseed debathena-loader.sh debathena
	git rev-parse --short HEAD > debathena/version
	tar czvf ${d}/debathena.tar.gz --exclude "*~" debathena
	cp debathena.preseed debathena-loader.sh ${d}
	rm debathena/version
