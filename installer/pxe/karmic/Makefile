# This is pretty dangerous in a bunch of ways.  Approach with caution.
d=/afs/dev/system/athena10/installer/karmic

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${d}/debathena-karmic.tar.gz

${d}/debathena-karmic.tar.gz: debathena-karmic.preseed debathena-karmic-loader.sh debathena-karmic
	tar czvf ${d}/debathena-karmic.tar.gz --exclude "*~" --exclude "*/.svn*" debathena-karmic
	cp debathena-karmic.preseed debathena-karmic-loader.sh ${d}
