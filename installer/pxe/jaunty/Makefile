# This is pretty dangerous in a bunch of ways.  Approach with caution.
d=/afs/dev/system/athena10/installer/jaunty

default:
	: Use "make install" to move this from where the installer will fetch it.

install: ${d}/debathena-jaunty.tar.gz

${d}/debathena-jaunty.tar.gz: debathena-jaunty.preseed debathena-jaunty-loader.sh debathena-jaunty
	tar czvf ${d}/debathena-jaunty.tar.gz --exclude "*~" --exclude "*/.svn*" debathena-jaunty
	cp debathena-jaunty.preseed debathena-jaunty-loader.sh ${d}
