
OUTFILE=min.exe

all:
	booc -r:ExCathedra.dll -keyfile:${SNK} -o:${OUTFILE} src/main/boo/*boo 

install: all
	sudo gacutil -i ${OUTFILE}
