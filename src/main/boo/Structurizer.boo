namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import C5
import System.Text
import System.Text.RegularExpressions
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

def StripMangler(start as string,end as string):
	return def(inp as string) as string:
		origLength = inp.Length
		inp = inp[start.Length:] if start and inp.StartsWith(start)
		inp = inp[:-end.Length] if end and inp.EndsWith(end)
		return inp if inp.Length != origLength
		return null

def RegexMangler(regx as Regex, replace as string):
	return def(inp as string) as string:
		return regx.Replace(inp,replace)

def TraceMangler(inp):
	print "Trace mangler, value: ${inp}"
	return

[Extension]
def AttrValue(el as XmlElement, attr as string) as string:
	atNode = el.Attributes[attr]
	return null if not atNode
	return atNode.Value

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

	MangleTypeName = JoinFunctions( DelegateMangler(typeMangle), RegexMangler(@/unsigned /,"u"), NameMapMangler(typeMap) )
	MangleFieldName = JoinFunctions( DelegateMangler(fieldMangle) )

	# context
	tu as XmlElement
	rs as XmlElement
	workingNameMap as IDictionary[of string,string]
	needed as IQueue[of string]

	def constructor():
		layout = Attribute("StructLayout")
		seq = MemberReferenceExpression(ReferenceExpression("LayoutKind"),"Sequential")
		layout.Arguments.Add(seq)
	
	def BuildModule(ast as XmlElement, *types as (string)):
		tu = ast["TranslationUnit"]
		rs = ast["ReferenceSection"]
		needed = LinkedList[of string]()
	
		# initial types
		for type in types:
			needed.Enqueue(type)
		BuildInitialNeeded() if needed.Count == 0
	
		# build name map
		BuildWorkingNameMap()
	
		# build module
		mod = Module()
		while needed.Count:
			name = needed.Dequeue()
			
			# lookup un-mangled names
			vintageName as string
			Find2(workingNameMap, name, vintageName)
			secondary as string
			secondary = "or @name = \"${vintageName}\"" if vintageName
			
			# find node
			typeEl = tu.SelectSingleNode("*[@name = \"${name}]\" ${secondary}]") as XmlElement
			if not typeEl:
				print "    Whoa, type ${name} not found!"
				continue
			
			# choose unmangled name
			name = MangleTypeName(name) if name == typeEl.AttrValue("name")
			
			# build
			member = BuildMember(typeEl,name)
			mod.Members.Add(member) if member
		return mod
	
	private def BuildInitialNeeded(*types as (string)):
		# build query for input files
		fileQueryList = List()
		marker = false
		for f as XmlElement in rs["Files"]:
			if not marker:
				marker = true if f.AttrValue("name") == "<scratch space>"
				continue
			fileId = f.AttrValue("id")
			fileQueryList.Add("@file = \"${fileId}\"")
		
		# spool elements from the input files
		fileQuery = fileQueryList.Join(" or ")
		query = "*[@name][${fileQuery}]"
		#query = "*[@name]"
		els = tu.SelectNodes(query)
		print "files [file count:${fileQueryList.Count}] [query:${fileQuery} type_count:${els.Count}]"
		for el as XmlElement in els:
			typeName = el.AttrValue("name")
			if typeName:
				print "adding ${typeName}"
				needed.Enqueue( typeName ) 
			else:
				print "    Missing typename [${ReadoutElement(el)}]" 
	
	private def BuildWorkingNameMap():
		workingNameMap = HashDictionary[of string,string]()
		for attr as XmlAttribute in tu.SelectNodes("*/@name"):
			name = attr.Value
			continue if not name
			typeName = MangleTypeName(name)
			continue if not typeName
			# print "map ${name}:${typeName}"
			workingNameMap[typeName] = name
	
	private def BuildMember(type as XmlElement,name) as TypeMember:
		result as TypeMember
		if type.Name == "Record":
			print "found ${name}"
			target = StructDefinition()
			target.Name = name
			target.Attributes.Add( layout )
			for field as XmlElement in type.ChildNodes:
				fieldMember = BuildField( field )
				target.Members.Add( fieldMember ) if fieldMember
			result = target
		else:
			pass
			#print "Unhandled construct [${entry.Name}, id: ${entry.Attributes['id'].Value}, type: ${entry.Attributes['type'].Value}]."
		
		#elif type.Name == "Typedef"
		#	pass
		#elif type.Name == "Enum"
		#	pass
		#elif type.Name == "Function":
		#	pass
		
		return result
	
	private def BuildField(field as XmlElement) as Field:
		rt = rs["Types"]
		
		fieldName = MangleFieldName( field.AttrValue("name") ) as string
		if not fieldName:
			print "   Whoa field has no name! [${ReadoutElement(field)}]"
			return null
		
		el = rt.SelectSingleNode("*[@id = \"${field.AttrValue('type')}\"]") as XmlElement
		if not el:
			print "   Whoa field type has no resolveable reference!  [${ReadoutElement(field)}]"
			return null
		
		# advanced lookup, not always needed or used.	
		target as XmlElement
		targetAttr = el.Attributes['type']
		if targetAttr:
			target = rt.SelectSingleNode("*[@id = \"${targetAttr.Value}\"]")
		
		fieldType as string
		verbose = false
		extra = ""
		if el.Name == "Record":
			fieldType = el.AttrValue("name")
		elif el.Name == "FundamentalType":
			fieldType = el.AttrValue("kind")
		elif el.Name == "Typedef":
			fieldType = "Int64"
			targetKind = target.AttrValue("kind")
			if target.Name == "FundamentalType" and targetKind:
				fieldType = targetKind
			else:
				verbose = true
		else:
			print "   Unhandled ${el.Name} resolve. [name: ${field.Attributes['name'].Value}]"
			fieldType = "Int32"
		
		if not fieldType:
			verbose = true
			extra += "[no fieldname]" 
			
		if verbose:
			sb = StringBuilder()
			if extra:
				sb.Append(extra)
				sb.Append(" ") 
			sb.Append("[field ")
			sb.Append(ReadoutElement(field))
			if el:
				sb.Append("] [el ") if el
				sb.Append(ReadoutElement(el)) if el
			if target:
				sb.Append("] [target ") if target
				sb.Append(target.Name) if target
				sb.Append(" ") if target
				sb.Append(ReadoutElement(target)) if target
			sb.Append("].")
			print "   Resolve ${el.Name} ${fieldType} ${sb.ToString()}" 
			
		fieldType = MangleTypeName(fieldType)
		fieldMember = Field( SimpleTypeReference(fieldType), null )
		fieldMember.Name = fieldName
		return fieldMember
		
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

	private def ReadoutElement(roel as XmlElement):
		sb = StringBuilder()
		for val in ("name","id","type","kind"):
			tmp = roel.AttrValue(val)
			continue if not tmp
			sb.Append(val)
			sb.Append(":")
			sb.Append(tmp)
			sb.Append(" ")
		sb.Remove(sb.Length-1,1)
		return sb.ToString()


doc = XmlDocument()
doc.Load(argv[0])

s = Structurizer()
mod = s.BuildModule(doc.DocumentElement)
mod.Name = "demoOne"
#print mod.ToCodeString()
