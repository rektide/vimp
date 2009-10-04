namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming

import C5

import Spring.Context.Support

import System
import System.IO
import System.Reflection.Emit
import System.Xml

import VoodooWarez.ExCathedra.Shell
import VoodooWarez.ExCathedra.Convert.Bytes



if argv.Length != 3:
	print "VoodooImport NAMESPACE OUTFILE INFILE.{c,h}..."
	return



# typedef / utility

print "Parameter configuration"

stringDict = HashDictionary[of string,string]

# select file

file = argv[2]
mod = Module()
modNamespace = argv[0]
mod.Namespace = NamespaceDeclaration(modNamespace)
asmParam = argv[1]
asmFile = asmParam
suffix = ".boo"
for ft in [ ".exe", ".dll", ".boo" ]:
	suffix = "" if asmFile.EndsWith("")
asmFile = asmFile+suffix
asmParam = asmFile[:-4]
print "asmParam", asmParam
mod.Name = asmFile

# find spring context

print "Spring loading root context"
rootContext = ContextRegistry.GetContext()
appContext = rootContext
print "Spring loading app contexts"
for suffix in [ ".config", ".xml" ]:
	try:
		print "looking at ${asmParam}${suffix}"
		appContext = XmlApplicationContext(asmParam+"Context",false,rootContext,"file://"+asmParam+suffix)
		print "found for root context file [file://${asmParam}${suffix}]!"
	except ex:
		#print "err ${ex}"
		pass
rootContext = appContext



# generate macro file

print ""
print "Macro enum processing"

macroProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc -E -dM ${file} -o $tmp").Start()
macroFile = macroProcess.StandardOutput.ReadLine()

#print "stdout", macroProcess.StandardOutput.ReadToEnd()
#print "stderr", macroProcess.StandardError.ReadToEnd()

try:
	while not macroProcess.HasExited:
		pass

	# build MacroEnumerizer & preferences
	
	menumerizer = rootContext.GetObject("MacroEnumerizer") as MacroEnumerizer
	menumerizer.BuildEnums(macroFile,mod)

ensure:
	File.Delete(macroFile)
	print "macro-error:", macroProcess.StandardError.ReadToEnd()



# generate structure file

print ""
print "Struct processing"

structProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc --ast-print-xml ${file} -o $tmp").Start()
structFile = structProcess.StandardOutput.ReadLine()

#print "stdout", structProcess.StandardOutput.ReadToEnd()
#print "stderr", structProcess.StandardError.ReadToEnd()

try:
	while not structProcess.HasExited:
		pass
	
	# load result doc

	structDoc = XmlDocument()
	structDoc.Load(structFile)

	# build Structurizer & preferences

	structurizer = rootContext.GetObject("Structurizer") as Structurizer
	structurizer.BuildStructs(structDoc.DocumentElement,mod)

ensure:
	File.Delete(structFile)
	print "struct error:", structProcess.StandardError.ReadToEnd()



# compile

print "Code generated; writing to file."

try:
	asmCode = asmParam+".boo"
	asmCodeFile = File.Open(asmCode, FileMode.Create, FileAccess.Write)
	
	code = mod.ToCodeString().GetAsciiBytes()
	asmCodeFile.Write( code, 0, code.Length )
ensure:
	asmCodeFile.Close() if asmCodeFile


#asmBuilder = compile(mod) as AssemblyBuilder
#asmBuilder.SetCustomAttribute(CustomAttributeBuilder( \
#	typeof(System.Reflection.AssemblyKeyNameAttribute).GetConstructors()[0], \
#	(asmParam,) ))
#asmBuilder.SetCustomAttribute(CustomAttributeBuilder( \
#	typeof(System.Reflection.AssemblyKeyFileAttribute).GetConstructors()[0], \
#	(keyFile,) ))
#asmBuilder.Save(asmFile)

print "Complete"
