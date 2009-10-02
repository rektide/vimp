
OUTFILE=vimp.exe

all:
	booc -r:ExCathedra.dll -r:Spring.Core.dll -keyfile:${SNK} -o:${OUTFILE} src/main/boo/*boo 

install: all
	sudo gacutil -i ${OUTFILE}
