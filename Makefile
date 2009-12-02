
OUTFILE=vimp.dll
HELPER=vimp.helper.dll

all: main helper

main:
	booc -r:ExCathedra.dll -r:Spring.Core.dll -keyfile:${SNK} -o:${OUTFILE} src/main/boo/*boo 

helper:
	booc -keyfile:${SNK} -o:${HELPER} src/main/boo/Serialization/*Helper*boo


install: all
	sudo gacutil -i ${OUTFILE}
	sudo gacutil -i ${HELPER}
	
	#rm -f vimp.dll
	#ln -sF ${OUTFILE} vimp.dll
	#sudo gacutil -i vimp.dll

