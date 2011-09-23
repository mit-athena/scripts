# This is pretty dangerous in a bunch of ways.  Approach with caution.
d=/afs/athena.mit.edu/system/athena10/installer/oneiric

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${d}/debathena.tar.gz

${d}/debathena.tar.gz: debathena.preseed debathena-loader.sh debathena
	tar czvf ${d}/debathena.tar.gz --exclude "*~" --exclude "*/.svn*" debathena
	cp debathena.preseed debathena-loader.sh ${d}
