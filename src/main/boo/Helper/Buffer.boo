namespace VoodooWarez.Systems.Import.Helper

import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.PatternMatching

import System
import System.Runtime.InteropServices



macro Buffer(name as ReferenceExpression, length as IntegerLiteralExpression):
	aname = "Buffer"+name.Name
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

macro StringBuffer (name as ReferenceExpression, length as IntegerLiteralExpression):
	aname = "StringBuffer"+name.Name
	tmp = [|
		[StructLayout(LayoutKind.Sequential)]
		struct $(aname):
			[MarshalAs (UnmanagedType.ByValTStr, SizeConst: $length)]
			public Value as String
	|]
	yield tmp

Buffer Four, 4
Buffer TFS, 256
Buffer K, 1024

StringBuffer TFS, 256
StringBuffer K, 1024
