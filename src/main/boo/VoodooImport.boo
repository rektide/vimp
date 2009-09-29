namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming

import System
import System.IO
import System.Reflection.Emit
import System.Xml

import VoodooWarez.ExCathedra.Shell



if argv.Length != 3:
	print "VoodooImport INFILE.{h.c} NAMESPACE OUTFILE"
	return



# select file

file = argv[0]
mod = Module()
modNamespace = argv[1]
asmFile = argv[2]
asmFile += ".dll" if not asmFile.EndsWith(".exe") and not asmFile.EndsWith(".dll")
mod.Name = asmFile
mod.Namespace = NamespaceDeclaration(modNamespace)


# generate macro file

macroProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc -E -dM ${file} -o $tmp").Start()
macroFile = macroProcess.StandardOutput.ReadLine()

while not macroProcess.HasExited:
	pass

# build MacroEnumerizer & preferences

menumerizer = MacroEnumerizer()
menumerizer.BuildEnums(macroFile,mod)

File.Delete(macroFile)



# generate structure file

structProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc --ast-print-xml ${file} -o $tmp").Start()
structFile = structProcess.StandardOutput.ReadLine()

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
