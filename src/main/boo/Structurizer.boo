namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import C5
import System.Xml

callable NameMangleDelegate(input as string) as string

[Extension]
def Find2[of T,U(class)](map as IDictionary[of T,U], key as T, ref obj as U):
""" workaround for bizarre unresolveable overrides of Find """
	try:
		obj = map[key]
	except sex as NoSuchItemException:
		obj = null

[Extension]
static def Find[of T](arr as (T), key as T):
	for i,el in enumerate(arr):
		return i if el == key
	return -1

[Extension]
static def Contains[of T](arr as (T), key as T):
	return Find[of T](arr,key) != -1

def JoinFunctions(*funcs as (callable)):
	return def(input):
		interm = input
		for f in funcs:
			try:
				temp = f(interm)
			except ex:
				continue
			interm = temp if temp
		return interm

def DelegateMangler(mangler as NameMangleDelegate):
	return def(input):
		return null if not mangler
		return mangler(input)

def NameMapMangler(map as IDictionary[of string,string]):
	return def(inp):
		return null if not map
		outp as string
		Find2[of string,string](map, inp as string, outp)
		return outp

def MapMangler[of T(class)](map as IDictionary[of T,T]):
	return def(inp as T) as T:
		return null if not map
		outp as T 
		Find2[of T,T](map, inp, outp)
		return outp

def TraceMangler(inp):
	print "Trace mangler, value: ${inp}"
	return

class Structurizer:

	enum ElementType:
		Typedef
		Record
		Function
		Enum

	layout as Attribute
	
	typeMangle as NameMangleDelegate
	typeMap as HashDictionary[of string,string]
	
	fieldMangle as NameMangleDelegate

	MangleTypeName = JoinFunctions( DelegateMangler(typeMangle), NameMapMangler(typeMap) )
	MangleFieldName = JoinFunctions( DelegateMangler(fieldMangle) )

	# context
	tu as XmlElement
	rs as XmlElement
	fs as (string)

	def constructor():
		layout = Attribute("StructLayout")
		seq = MemberReferenceExpression(ReferenceExpression("LayoutKind"),"Sequential")
		layout.Arguments.Add(seq)

	def DoDocument(ast as XmlElement, *types as (string)):
		tu = ast["TranslationUnit"]
		rs = ast["ReferenceSection"]
		
		FindInputFiles()
		mod = BuildModule(ast,*types)
		return mod

	private def FindInputFiles():
		fsl = List()
		marker = false
		for f as XmlElement in rs["Files"]:
			if f.Attributes["name"].Value == "<scratch space>":
				marker = true 
				continue
			else:
				continue if not marker
			fsl.Add(f.Attributes["id"].Value)
		fs = fsl.ToArray(string)
	
	private def BuildModule (ast as XmlElement, *types as (string)):
		mod = Module()
		for entry as XmlElement in tu.ChildNodes:
			name = entry.Attributes["name"].Value
			continue if not name
			typeName = MangleTypeName(name)
			if types.Length:
				continue if not Contains[of string](types,name) and not Contains[of string](types,typeName)
			else:	
				file = entry.Attributes["file"]
				continue if not file or not Contains[of string](fs,entry.Attributes["file"].Value)
		
			if entry.Name == "Record":
				print "found ${typeName}"
				target = StructDefinition()
				target.Name = typeName
				target.Attributes.Add( layout )
				for field as XmlElement in entry.ChildNodes:
					fieldType = ResolveFieldType(field)
					fieldName = MangleFieldName( field.Attributes["name"].Value ) as string
					fieldMem = Field( SimpleTypeReference(fieldType), null )
					fieldMem.Name = fieldName
					target.Members.Add( fieldMem )
				mod.Members.Add(target)
			else:
				print "Unhandled construct [${entry.Name}, id: ${entry.Attributes['id'].Value}, type: ${entry.Attributes['type'].Value}]."
			
			#elif entry.Name == "Typedef"
			#	pass
			#elif entry.Name == "Enum"
			#	pass
			#elif entry.Name == "Function":
			#	pass
		return mod

	def ResolveFieldType(field as XmlElement) as string:
		el = rs["Types"].SelectSingleNode("*[@id = \"${field.Attributes['type'].Value}\"]")
		result as string
		if el.Name == "Record":
			result = el.Attributes["name"].Value
		elif el.Name == "FundamentalType":
			result = el.Attributes["kind"].Value
		else:
			print "Unhandled field resolve ${el.Name}"
			return "Int32"
		return MangleTypeName(result)

		#elif el.Name == "Typedef":
		#	pass
		#elif el.Name == "PointerType":
		#	pass
		#elif el.Name == "ArrayType":
		#	pass
		#elif el.Name == "TypeOfExprType":
		#	pass
		#elif el.Name == "FunctionType":
		#	pass


doc = XmlDocument()
doc.Load(argv[0])

s = Structurizer()
mod = s.DoDocument(doc.DocumentElement)
mod.Name = "demoOne"
print mod.ToCodeString()
