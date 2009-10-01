namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler.Ast

import C5

import System
import System.IO

import VoodooWarez.ExCathedra.C6
import VoodooWarez.ExCathedra.Convert
import VoodooWarez.ExCathedra.Mangle



class MacroEnumerizer:
""" Translate C preprocessor macro objects into Enums """
	
	def constructor():
		pass

	objectParse = @/^#define\s+([\w_]+)\s+(.*)$/
	objectNameClean = @/^[_\W]+/

	intParser = IntegerLiteralParser()
	
	#[Property(EnumNameMangler)] nameMangler as NameMangleDelegate
	#[Property(EnumMemberMangler)] memberMangler as NameMangleDelegate
	
	[Property(EnumMap)] 
	enumMap = HashDictionary[of string,string]()
	""" maps from a macro prefix to a enum name """
	
	[Property(EnumMangler)]
	enumMangler as (IMangle)
	[Property(EnumMemberMangler)]
	enumMemberMangler as (IMangle)
	
	protected MangleEnumName as callable:
		get:
			return JoinMangler(*enumMangler).CallableMangler()
	protected MangleMemberName as callable:
		get:
			return JoinMangler(*enumMemberMangler).CallableMangler()

	def BuildEnums(file as string) as Module:
		return BuildEnums(file,Module())
	
	def BuildEnums(file as string, mod as Module) as Module:
		enums = HashDictionary[of string,EnumDefinition]()
		
		# parse enums out of file
		sr = StreamReader(file)
		try:
			while sr.Peek() >= 0:
				line = objectParse.Match(sr.ReadLine())
				continue if line.Groups.Count < 3
				objName = line.Groups[1].Value
				objValue = line.Groups[2].Value 
				for key in enumMap.Keys:
					continue if not objName.StartsWith(key)
					try:
						enumMemberName = objName[key.Length:]
						enumMemberName = MangleMemberName(enumMemberName)
						
						enumName = key
						enumName = MangleEnumName(enumName)
						
						enumDefinition as EnumDefinition
						enums.Find2(enumName,enumDefinition)
						if not enumDefinition:	
							enumDefinition = EnumDefinition()
							enumDefinition.Name = enumName
							enums.Add(enumName, enumDefinition)
						
						# find optional value
						enumMember as EnumMember
						try:
							enumVal = intParser.Convert(objValue)
							enumMember = EnumMember(IntegerLiteralExpression(enumVal))
						except icex as InvalidCastException:
							#enumMember = EnumMember()
							print "Ignoring [${enumMember}] in [${enumName}] from [${objName},${objValue}], for it has no value."
							break
						enumMember.Name = enumMemberName
						
						print "Adding [${enumMember}, ${enumVal}] to [${enumName}] from raw [${objName},${objValue}]"
						
						enumDefinition.Members.Add(enumMember)
						break
					except:
						pass
		except ex:
			print "Loop exception;", ex
		ensure:
			sr.Close()
		
		for member in enums:
			mod.Members.Add(member.Value)
		return mod
