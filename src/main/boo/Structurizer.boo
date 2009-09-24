namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.MetaProgramming
import C5
import System
import System.Reflection.Emit
import System.Runtime.InteropServices
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

def NameMapMangler(nmap as IDictionary[of string,string]):
	return def(inp):
		return null if not nmap
		outp as string
		Find2[of string,string](nmap, inp as string, outp)
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

	layout as Boo.Lang.Compiler.Ast.Attribute

	[Property(TypeMap)]
	typeMap as IDictionary[of string,string]
	[Property(TypeMangle)]	
	typeMangle as NameMangleDelegate
	
	[Property(FieldMangle)]
	fieldMangle as NameMangleDelegate

	protected MangleTypeName as callable:
		get: 
			return JoinFunctions( DelegateMangler(typeMangle), RegexMangler(@/unsigned /,"u"), NameMapMangler(typeMap) )
	protected MangleFieldName as callable:
		get: 
			return JoinFunctions( DelegateMangler(fieldMangle) )

	[Property(NamespaceImports)]
	namespaceImports as ICollection[of string]

	# context
	tu as XmlElement
	rs as XmlElement
	workingNameMap as IDictionary[of string,string]
	needed as IList[of string]

	def constructor():
		layout = Boo.Lang.Compiler.Ast.Attribute("StructLayout")
		seq = MemberReferenceExpression(ReferenceExpression("LayoutKind"),"Sequential")
		layout.Arguments.Add(seq)
		
		typeMap = HashDictionary[of string,string]()
		typeMap["char"] = "byte"
		typeMap["uchar"] = "byte"

		namespaceImports = ArrayList[of string]()	
		namespaceImports.Add("System.Runtime.InteropServices")

	def BuildModule(ast as XmlElement, *types as (string)):
		return BuildModule(ast, Module(), *types)

	def BuildModule(ast as XmlElement, mod as Module, *types as (string)):
		tu = ast["TranslationUnit"]
		rs = ast["ReferenceSection"]
		needed = LinkedList[of string]()
	
		# initial types
		for type in types:
			EnsureNativeType(type)
		BuildInitialNeeded() if needed.Count == 0
	
		# build name map
		BuildWorkingNameMap()
	
		# build module
		i = 0
		while i < needed.Count: 
			name = needed[i++]
			
			# lookup un-mangled names
			vintageName as string
			Find2(workingNameMap, name, vintageName)
			secondary as string
			secondary = "or @name = \"${vintageName}\"" if vintageName
			
			# find node
			typeEl = tu.SelectSingleNode("*[@name = \"${name}]\" ${secondary}]") as XmlElement
			if not typeEl:
				print "   Whoa, type ${name} not found!"
				
				continue
			
			# choose unmangled name
			name = MangleTypeName(name) if name == typeEl.AttrValue("name")
			
			# build
			try:
				member = BuildMember(typeEl,name)
				mod.Members.Add(member) if member
			except ex:
				print "   [failed to build ${name}] ${ex}"
		# add imports
		for impStr in namespaceImports:
			imp = Import()
			imp.Namespace = impStr
			mod.Imports.Add( imp )
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
		query = "*[@name]"
		els = tu.SelectNodes(query)
		print "files [file count:${fileQueryList.Count}] [query:${fileQuery} type_count:${els.Count}]"
		for el as XmlElement in els:
			typeName = el.AttrValue("name")
			if typeName:
				#print "adding ${typeName}"
				EnsureNativeType( typeName )
			else:
				print "   Missing typename [${ReadoutElement(el)}]" 
	
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
		fieldName = MangleFieldName( field.AttrValue("name") ) as string
		if not fieldName:
			raise Exception("Whoa field has no name! [${ReadoutElement(field)}]")
	
		el = FetchTypeById(field.AttrValue('type'))
		if not el:
			raise Exception("Whoa field type has no resolveable reference!  [${ReadoutElement(field)}]")
		
		# advanced lookup, not always needed or used.	
		target as XmlElement
		targetId = el.AttrValue("type")
		if targetId:
			target = FetchTypeById(targetId)
		
		fieldType as TypeReference	
		fieldTypeName as string
		attrs = List[of Boo.Lang.Compiler.Ast.Attribute]()
		verbose = false
		extra = ""

		def DebugPrint():
			sb = StringBuilder()
			sb.Append("[Resolve ")
			sb.Append(el.Name)
			sb.Append(" ")
			sb.Append(fieldTypeName) if fieldTypeName
			sb.Append(fieldType.ToCodeString()) if not fieldTypeName and fieldType
			sb.Append("null") if not fieldTypeName and not fieldType
			sb.Append("] ")
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
			return sb.ToString()
	
		if el.Name == "Record":
			fieldTypeName = el.AttrValue("name")
		elif el.Name == "FundamentalType":
			fieldTypeName = el.AttrValue("kind")
		elif el.Name == "Typedef":
			fieldTypeName = ResolveTypedefTarget(target)
		elif el.Name == "PointerType":
			fieldTypeName = "object"
		elif el.Name == "ArrayType":
			verbose = true
	
			sizeConst = Int32.Parse(el.AttrValue("size"))
			marshalAttr = BuildMarshalAs( sizeConst )	
			attrs.Add( marshalAttr )
			
			arrType as TypeReference
			if target.Name == "FundamentalType":
				arrTypeName = target.AttrValue("kind")
			elif target.Name == "Record":
				arrTypeName = target.AttrValue("name")
			elif target.Name == "Typedef":
				type2 = target.AttrValue("type")
				raise Exception("Invalid typedef type for array. ${DebugPrint()}") if not type2
				target2 = FetchTypeById(type2) as XmlElement
				arrTypeName = ResolveTypedefTarget(target2)
			
			if not arrTypeName:
				raise Exception("ArrayType cannot discern type. ${DebugPrint()}")
		
			arrTypeName = MangleTypeName( arrTypeName ) as string
			EnsureNativeType(arrTypeName)

			fieldType = ArrayTypeReference( SimpleTypeReference(arrTypeName) )
		else:
			raise Exception("Unhandled ${el.Name} resolve. ${DebugPrint()}")
		
		if not fieldTypeName and not fieldType:
			raise Exception("Unhandled implicit declaration. ${DebugPrint()}")
			#verbose = true
			#extra += "[no fieldname]" 
		
		if fieldTypeName:
			fieldTypeName = MangleTypeName(fieldTypeName) 
			fieldType = SimpleTypeReference(fieldTypeName)
			EnsureNativeType(fieldTypeName)
		
		if verbose:
			print "   ${DebugPrint()}"
		
		fieldMember = Field( fieldType, null )
		fieldMember.Name = fieldName
		for attr in attrs:
			fieldMember.Attributes.Add(attr)
		return fieldMember
		
		#elif el.Name == "ArrayType":
		#	pass
		#elif el.Name == "TypeOfExprType":
		#	pass
		#elif el.Name == "FunctionType":
		#	pass

	private def EnsureNativeType(id as string):
		mangledId = MangleTypeName(id)
		return if needed.Contains(id) or needed.Contains(mangledId)
		needed.Add(id)

	private def EnsureWrappedType(id as string):
		return if needed.Contains(id)
		needed.Add(id)

	private def FetchTypeById(id as string):
		return rs["Types"].SelectSingleNode("*[@id = \"${id}\"]") as XmlElement
			
	
	private def ResolveTypedefTarget(target as XmlElement) as string:
		if target.Name == "FundamentalType":
			return target.AttrValue("kind")
		elif target.Name == "Record":
			return target.AttrValue("name")
		elif target.Name == "PointerType":
			return "object"
		else:
			raise NotImplementedException("Unhandled typedef target ${target.Name}.")

	private def ReadoutElement(roel as XmlElement):
		sb = StringBuilder()
		for val in ("name","id","type","kind","size"):
			tmp = roel.AttrValue(val)
			continue if not tmp
			sb.Append(val)
			sb.Append(":")
			sb.Append(tmp)
			sb.Append(" ")
		sb.Remove(sb.Length-1,1)
		return sb.ToString()

	private def BuildMarshalAs(sizeConst as int):
		marshalAs = Boo.Lang.Compiler.Ast.Attribute("MarshalAs")
		
		byValArg = MemberReferenceExpression(ReferenceExpression("UnmanagedType"),"ByValArray")
		marshalAs.Arguments.Add(byValArg)
		
		sizeConstArg = ExpressionPair(ReferenceExpression("SizeConst"), IntegerLiteralExpression(sizeConst))
		marshalAs.NamedArguments.Add(sizeConstArg)

		return marshalAs


doc = XmlDocument()
doc.Load(argv[0])

s = Structurizer()
mod = s.BuildModule(doc.DocumentElement)
mod.Name = "demoOne"
compile(mod) 
