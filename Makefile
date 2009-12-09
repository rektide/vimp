
OUTFILE=vimp.dll
HELPER=vimp.helper.dll
BOOC_OPTS=-debug

all: main helper

main:
	booc ${BOOC_OPTS} -r:ExCathedra.dll -r:Spring.Core.dll -keyfile:${SNK} -o:${OUTFILE} src/main/boo/*boo 

helper:
	booc ${BOOC_OPTS} -keyfile:${SNK} -o:${HELPER} src/main/boo/Helper/*boo


install: all
	sudo gacutil -i ${OUTFILE}
	sudo gacutil -i ${HELPER}
	
	#rm -f vimp.dll
	#ln -sF ${OUTFILE} vimp.dll
	#sudo gacutil -i vimp.dll

