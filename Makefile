
OUTFILE=vimp.dll

all:
	booc -r:ExCathedra.dll -r:Spring.Core.dll -keyfile:${SNK} -o:${OUTFILE} src/main/boo/*boo 

install: all
	sudo gacutil -i ${OUTFILE}
	
	#rm -f vimp.dll
	#ln -sF ${OUTFILE} vimp.dll
	#sudo gacutil -i vimp.dll

