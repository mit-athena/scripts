# Don't look, don't use.  Icky.
d=/afs/dev/system/athena10/installer/intrepid

${d}/athena10-intrepid.tar.gz: athena10-intrepid.preseed athena10-intrepid-loader.sh pxe.config athena10-intrepid
	tar czvf ${d}/athena10-intrepid.tar.gz --exclude "*~" athena10-intrepid
	cp athena10-intrepid.preseed athena10-intrepid-loader.sh ${d}
