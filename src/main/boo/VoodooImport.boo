namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming

import System
import System.Reflection.Emit
import System.Xml

import VoodooWarez.ExCathedra.Shell



if argv.Length != 1:
	print "VoodooWimport input.{h.c}"
	return



# select file

file = argv[0]
mod = Module()
mod.Name = argv[1]
asmFile = argv[2]



# generate macro file

macroProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc -E -dM ${file} -o $tmp").Start()
macroFile = macroProcess.StandardOutput.ReadLine()

# build MacroEnumerizer & preferences

menumerizer = MacroEnumerizer()
menumerizer.BuildEnums(macroFile,mod)



# generate structure file

structProcess = BashCommand("tmp=`mktemp`; echo $tmp; clang-cc --ast-print-xml ${file} -o $tmp").Start()
structFile = structProcess.StandardOutput.ReadLine()

structDoc = XmlDocument()
structDoc.Load(structFile)

# build Structurizer & preferences

structurizer = Structurizer()
structurizer.BuildStructs(structDoc.DocumentElement)



# compile

asmBuilder = compile(mod) as AssemblyBuilder
asmBuilder.Save(asmFile)
