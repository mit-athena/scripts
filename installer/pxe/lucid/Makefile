# This is pretty dangerous in a bunch of ways.  Approach with caution.
d=/afs/dev/system/athena10/installer/lucid

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${d}/debathena.tar.gz

${d}/debathena.tar.gz: debathena.preseed debathena-loader.sh debathena
	tar czvf ${d}/debathena-lucid.tar.gz --exclude "*~" --exclude "*/.svn*" debathena
	cp debathena.preseed debathena-loader.sh ${d}
