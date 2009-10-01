namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming

import C5

import Spring.Core
import Spring.Context.Support
import Spring.Objects.Factory

import System
import System.IO
import System.Reflection.Emit
import System.Xml

import VoodooWarez.ExCathedra.Shell



if argv.Length != 3:
	print "VoodooImport NAMESPACE OUTFILE [CONFIGFILE] INFILE.{c,h}..."
	return



# typedef / utility

stringDict = HashDictionary[of string,string]

# select file

file = argv[2]
mod = Module()
modNamespace = argv[0]
mod.Namespace = NamespaceDeclaration(modNamespace)
asmParam = argv[1]
asmFile = asmParam
asmFile += ".dll" if not asmFile.EndsWith(".exe") and not asmFile.EndsWith(".dll")
asmParam = asmFile[:-4]
mod.Name = asmFile

# find spring context

rootContext = ContextRegistry.GetContext()
#for suffix in [ ".config", ".xml" ]:
for suffix in [ ".config" ]:
	try:
		print "looking at ${asmParam}${suffix}"
		appContext = XmlApplicationContext(asmParam+"Context",false,rootContext,"file://"+asmParam+suffix)
		print "found a root context [file://${asmParam}${suffix}]!"
	except ex:
		print "err ${ex}"
	rootContext = appContext if appContext


# generate macro file

macroProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc -E -dM ${file} -o $tmp").Start()
macroFile = macroProcess.StandardOutput.ReadLine()

#print "stdout", macroProcess.StandardOutput.ReadToEnd()
#print "stderr", macroProcess.StandardError.ReadToEnd()

while not macroProcess.HasExited:
	pass

# build MacroEnumerizer & preferences

menumerizer = MacroEnumerizer()

try:
	enm = rootContext.GetObject("EnumMap", stringDict) as HashDictionary[of string,string]
	menumerizer.EnumMap = enm
except nso as NoSuchObjectDefinitionException:
	print "No such object; frak!"
	return
#except onType ObjectNotOfRequiredTypeException:
#	pass

#	enm = rootContext.GetObject("EnumMemberMangler", stringDict)
#	enm = rootContext.GetObject("TypeMap", stringDict)
#	enm = rootContext.GetObject("TypeMangler", stringDict)
#	enm = rootContext.GetObject("TypeFieldMangler", stringDict)

menumerizer.BuildEnums(macroFile,mod)

File.Delete(macroFile)



# generate structure file

structProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc --ast-print-xml ${file} -o $tmp").Start()
structFile = structProcess.StandardOutput.ReadLine()

#print "stdout", structProcess.StandardOutput.ReadToEnd()
#print "stderr", structProcess.StandardError.ReadToEnd()

while not structProcess.HasExited:
	pass

structDoc = XmlDocument()
structDoc.Load(structFile)

# build Structurizer & preferences

structurizer = Structurizer()
structurizer.BuildStructs(structDoc.DocumentElement,mod)

File.Delete(structFile)



# compile

asmBuilder = compile(mod) as AssemblyBuilder
asmBuilder.Save(asmFile)

print "Complete"
