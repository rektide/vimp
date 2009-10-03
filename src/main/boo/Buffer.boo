namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming
import Boo.Lang.PatternMatching

import System
import System.Runtime.InteropServices
import System.Text

import VoodooWarez.ExCathedra.Convert
import VoodooWarez.ExCathedra.Convert.Bytes
import VoodooWarez.Systems.Import



macro Buffer(name as ReferenceExpression, length as IntegerLiteralExpression):
	aname = "Buffer"+name.Name
	name.Name = "Buffer"+name.Name
	tmp = [|
		[StructLayout(LayoutKind.Explicit)]
		struct $(aname):
			BufferFields $(length.Value)
	|]
	yield tmp

macro BufferFields (length as IntegerLiteralExpression):
	for i in range(0,length.Value):
		name = "Num${i}"
		tmp = [| 
			[FieldOffset($i)]
			public $name as byte 
		|]
		yield tmp


Buffer Four, 4
Buffer TFS, 256
Buffer K, 1024

