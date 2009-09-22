namespace VoodooWarez.Systems

import Boo.Lang.Compiler.Ast
import C5
import System.Text
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

	MangleTypeName = JoinFunctions( DelegateMangler(typeMangle), NameMapMangler(typeMap) )
	MangleFieldName = JoinFunctions( DelegateMangler(fieldMangle) )

	# context
	tu as XmlElement
	rs as XmlElement
	fs as (string)

	needed as IQueue[of string]

	def constructor():
		layout = Attribute("StructLayout")
		seq = MemberReferenceExpression(ReferenceExpression("LayoutKind"),"Sequential")
		layout.Arguments.Add(seq)
	
	def DoDocument(ast as XmlElement, *types as (string)):
		tu = ast["TranslationUnit"]
		rs = ast["ReferenceSection"]
		needed = LinkedList[of string]()

		FindInputFiles()
		mod = BuildModule(*types)
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
	
	private def BuildModule (*types as (string)):
		mod = Module()
		for entry as XmlElement in tu.ChildNodes:
			name = entry.Attributes["name"].Value
			continue if not name
			typeName = MangleTypeName(name)
			if types.Length:
				continue if not Contains[of string](types,name) and not Contains[of string](types,typeName)
			else:	
				file = entry.Attributes["file"]
				#continue if not file or not Contains[of string](fs,entry.Attributes["file"].Value)
		
			if entry.Name == "Record":
				print "found ${typeName}"
				target = StructDefinition()
				target.Name = typeName
				target.Attributes.Add( layout )
				for field as XmlElement in entry.ChildNodes:
					fieldMember = BuildField( field )
					target.Members.Add( fieldMember ) if fieldMember
				mod.Members.Add(target)
			else:
				pass
				#print "Unhandled construct [${entry.Name}, id: ${entry.Attributes['id'].Value}, type: ${entry.Attributes['type'].Value}]."
			
			#elif entry.Name == "Typedef"
			#	pass
			#elif entry.Name == "Enum"
			#	pass
			#elif entry.Name == "Function":
			#	pass
		return mod

	def BuildField(field as XmlElement) as Field:
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
mod = s.DoDocument(doc.DocumentElement)
mod.Name = "demoOne"
#print mod.ToCodeString()
