namespace VoodooWarez.Utils

import Boo.Lang.Compiler.Ast

import C5

import System
import System.IO
import System.Text.RegularExpressions


interface IConverter[of Src,Dest]:
	def Convert(src as Src) as Dest

abstract class SuffixedParser:
	suffixes as (string)
	def constructor(suffixes as (string)):
		self.suffixes = suffixes
	def ChompSuffix(ref str as string) as string:
		for fix in suffixes:
			continue if not str.EndsWith(fix)
			str = str[:-fix.Length]
			return fix
		return null

class FloatLiteralParser(SuffixedParser,IConverter[of string,Double]):
	def constructor():
		# float literal specifiers
		# http://publib.boulder.ibm.com/infocenter/iadthelp/v7r0/topic/com.ibm.etools.iseries.langref.doc/as400clr37.htm#HDRFC
		super( ("F", "f", "L", "l") )
	
	def Convert(inp as string) as Double:
		suffix = ChompSuffix(inp)
		try:
			return Double.Parse(inp)
		failure:
			pass
		raise InvalidCastException()
		

class IntegerLiteralParser(SuffixedParser,IConverter[of string,Int64]):
	def constructor():
		# integeral literal specifiers:
		# http://publib.boulder.ibm.com/infocenter/iadthelp/v7r0/topic/com.ibm.etools.iseries.langref.doc/as400clr36.htm#HDRIC
		super( ("LL","ll","L","l","U","u") )
	
	def Convert(inp as string) as Int64:
		suffix = ChompSuffix(inp)
		if inp.StartsWith("0x") or inp.StartsWith("0X"):
			try:
				return Int64.Parse(inp[-2:],Globalization.NumberStyles.AllowHexSpecifier)
			failure:
				pass
		if inp.StartsWith("0"):
			try:
				return System.Convert.ToInt64(inp,8) if inp.StartsWith("0")
			failure:
				pass
		try:
			return System.Convert.ToInt64(inp)
		failure:
			pass
		raise InvalidCastException()
		

class StringLiteralParser(IConverter[of string,string]):
	stringDelims = ("\"", "'")	
	def Convert(inp as string) as string:
		for delim in stringDelims:
			return inp[delim.Length:-delim.Length] if inp.StartsWith(delim) and inp.EndsWith(delim)
		raise InvalidCastException()
		
class BooleanLiteralParser(IConverter[of string,bool]):
	def Convert(inp as string) as bool:
		return true if inp == "true"
		return false if inp == "false"
		raise InvalidCastException()


class MacroEnumerizer:
""" Translate C preprocessor macro objects into Enums """
	
	def constructor():
		pass

	objectParse = @/#define\s+(\S)(?:\s+(.*))?$/
	objectNameClean = @/^\W+/

	intParser = IntegerLiteralParser()
	
	callable NameMangleDelegate(input as string) as string

	[Property(EnumNameMangler)] nameMangler as NameMangleDelegate
	[Property(EnumNemberMangler)] memberMangler as NameMangleDelegate
	
	[Property(EnumMap)] enumMap = HashDictionary[of string,string]()
	""" maps from a macro prefix to a enum name """

	def BuildEnums(file as string, ns as string):
		enums = HashDictionary[of string,EnumDefinition]()
		
		# parse enums out of file
		sr = StreamReader(file)
		try:
			while sr.Peek() >= 0:
				line = objectParse.Match(sr.ReadLine())
				objName = line.Captures[0].Value
				objValue = null
				objValue = line.Captures[1].Value if line.Captures.Count > 1
				for key in enumMap.Keys:
					continue if not objName.StartsWith(key)
					try:
						enumMemberName = objName[-key.Length:]
						enumMemberName = objectNameClean.Replace(enumMemberName, "")
						enumMemberName = memberMangler(enumMemberName) if memberMangler
						
						enumName = key
						enumName = nameMangler(enumName) if nameMangler
						enumDefinition as EnumDefinition
						#right way to do it, but crazy unhandleable ambiguous overload insanity in C5:
						#enums.Find(enumName, enumDefinition)
						try:
							enumDefinition = enums[enumName]
						except:
							pass
						if not enumDefinition:	
							enumDefinition = EnumDefinition()
							enumDefinition.Name = enumName
							enums.Add(enumName, enumDefinition)
							
						# find optional value
						enumMember as EnumMember
						try:
							enumVal = intParser.Convert(objValue)
							enumMember = EnumMember(IntegerLiteralExpression(enumVal))
						except InvalidCastException:
							enumMember = EnumMember()
						enumMember.Name = enumMemberName
						
						enumDefinition.Members.Add(enumMember)
					except:
						pass
		ensure:
			sr.Close()
		
		# render enums into assembly
		mod = Module()
		mod.Namespace = NamespaceDeclaration(ns)
		for member in enums:
			mod.Members.Add(member.Value)
		return mod
