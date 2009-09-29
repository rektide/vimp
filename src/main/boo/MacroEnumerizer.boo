namespace VoodooWarez.Systems.Import

import Boo.Lang.Compiler.Ast

import C5

import System
import System.IO

import VoodooWarez.ExCathedra.Convert



class MacroEnumerizer:
""" Translate C preprocessor macro objects into Enums """
	
	def constructor():
		pass

	objectParse = @/^#define\s+([\w_]+)\s+(.*)$/
	objectNameClean = @/^[_\W]+/

	intParser = IntegerLiteralParser()
	
	callable NameMangleDelegate(input as string) as string

	[Property(EnumNameMangler)] nameMangler as NameMangleDelegate
	[Property(EnumMemberMangler)] memberMangler as NameMangleDelegate
	
	[Property(EnumMap)] enumMap = HashDictionary[of string,string]()
	""" maps from a macro prefix to a enum name """

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
						enumMemberName = objectNameClean.Replace(enumMemberName, "")
						if memberMangler:
							try:
								proposed = memberMangler(enumMemberName)
								enumMemberName = proposed if proposed
							except ex:
								pass
						
						enumName = key
						enumName = nameMangler(enumName) if nameMangler
						try:
							enumName = enumMap[enumName]
						except:
							pass
						enumDefinition as EnumDefinition
						#right way to do it, but crazy unhandleable ambiguous overload insanity in C5:
						#enums.Find(enumName, enumDefinition)
						try:
							enumDefinition = enums[enumName]
						except noSuch as NoSuchItemException:
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
