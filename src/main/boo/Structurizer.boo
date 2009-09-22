namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import C5
import System.Xml

callable NameMangleDelegate(input as string) as string

[Extension]
def Find2[of T,U](map as IDictionary[of T,U], key as T, ref obj as U):
	""" workaround for bizarre unresolveable overrides of Find """
	try:
		obj = map[key]
	catch ex:
		obj = null

class Structurizer:

	enum ElementType:
		Typedef,
		Record,
		Function,
		Enum

	layout as Attribute
	
	typeMangle as NameMangleDelegate
	typeMap as HashDictionary[of string,string]
	
	fieldMangle as NameMangleDelegate

	# context
	tu as XmlElement
	rs as XmlElement	
	typeIds as HashDictionary[of string, XmlElement]

	def constructor():
		layout = Attribute("StructLayout)
		seq = MemberReferenceExpression(ReferenceExpression("LayoutKind"),"Sequential")
		layout.Arguments.Add(seq)
	
	def Structurize(ast as XmlDocument, types as *string):
		m = ModuleDefinition()
		tu = ast["TranslationUnit"]
		rs = ast["ReferenceSection"]
		
		# preparse all type's
		typeIds = HashDictionary[of string, XmlElement]()
		for type as XmlElement in rs["Types"]:
			typeIds[type.Attributes["id"]] = type
		
		for entry in tu:
			name = entry.Attributes["name"]
			continue if not name
			continue if types and types.Length and not types.Contains(name)
			if entry.Name == "Record"
				target = StructDefinition()
				typeName = typeMangle(name)
				target.Name = typeName
				target.Attributes.Add( layout )
				for field as XmlElement in entry.ChildNodes:
					fieldType = typeMangle()
					fieldName = field.Attributes["name"]
					fieldName = mangleFieldName(fieldName) if mangleFieldName
					field = Field( TypeReference(fieldType), fieldName )
					target.Members.Add( field )
			elif entry.Name == "Typedef"
				pass
			elif entry.Name == "Enum"
				pass
			elif entry.Name == "Function":
				pass

	def ResolveFieldType(field as XmlElement) as string:
		el = typeIds[field.Attributes["type"]]
		if el.Name == "Record":
			return TypeMangle( el.Attributes["name"] )
		elif el.Name == "Typedef":
			
			typeroot = typeIds[ el.Attributes["type"] ]
			
		elif el.Name == "FundamentalType":
			pass
		elif el.Name == "PointerType":
			pass
		elif el.Name == "ArrayType":
			pass
		elif el.Name == "TypeOfExprType":
			pass
		elif el.Name == "FunctionType":
			pass

	def TypeMangle(input as string) as string:
		typeName = input
		typeName = typeMangle(typeName) if typeMangle
		typeName = typeMap[typeName] if typeMap.Contains(typeName)
		return typeName
