namespace VoodooWarez.Systems.Import.Helper

import Boo.Lang.Compiler.MetaProgramming

import System
import System.Collections
import System.Collections.Generic
import System.Reflection
import System.Runtime.InteropServices
import System.Threading



interface ISerializable:
	def Serialize() as (byte):
		pass
	def Deserialize(o as (byte), start as int):
		pass

interface ISerializer:
	def Serialize(o) as (byte):
		pass
	def Deserialize(o as (byte), start as int):
		pass
	Size as int:
		get
	Type as Type:
		get

interface ISerializer[of T](ISerializer):
	def Serialize(o as T) as (byte):
		pass
	def Deserialize(o as (byte), start as int) as T:
		pass

interface ISerializerProvider (IEnumerable[of ISerializer]):
	pass

class StructSerializerProvider (ISerializerProvider):
	serializant as ISerializable
	
	def constructor(serializant as ISerializable):
		pass
	
	Relations as IEnumerator[of ISerializer]:
		get:
			pass
	
	def System.Collections.IEnumerable.GetEnumerator() as IEnumerator:
		return Relations
	def GetEnumerator() as IEnumerator[of ISerializer]:
		return Relations
	
class AutoStaticSerializerProvider (ISerializerProvider):

	source as Type
	toBytePattern as regex
	bytesType = typeof((byte))
	intType = typeof(int)
	
	providerInstance as int
	relationInstance as int
	
	static instanceIter = 0
	
	def constructor(source as Type):
		self(source, /GetBytes/)
	
	def constructor(source as Type, toBytePattern as regex):
		self.source = source
		self.toBytePattern = toBytePattern
		self.providerInstance = Interlocked.Increment(instanceIter)

		methods = source.GetMethods()
		for ser as MethodInfo in methods:
			# identify serializer methods
			continue if not toBytePattern.Match(ser.Name)
			continue if not ser.IsStatic
			continue if not ser.ReturnType == bytesType
			prms = ser.GetParameters()
			continue if not prms.Length == 1
			
			# identify targetType for this serializer method
			targetType  = prms[0].ParameterType
			
			# find reciprocal deserial method
			deser as MethodInfo
			for deser as MethodInfo in methods:
				continue if not deser.IsStatic
				continue if not deser.ReturnType != targetType
				dsprms = deser.GetParameters()
				continue if not dsprms.Length == 2
				continue if not dsprms[0].ParameterType == bytesType
				continue if not dsprms[1].ParameterType == intType
				break
			continue if not deser
			
			# find size via a run on a default instance
			instance = Activator.CreateInstance(targetType)
			bytes = ser.Invoke(null, (instance,) ) as (byte)
			size = bytes.Length
		
			# retrieve names
			typeName = targetType.FullName
			sourceName = source.FullName
			klassName = "_SerialRelation_$(providerInstance)_$(relationInstance++)"
			
			klass = [|
				class $(klassName) ( ISerializer[of $(typeName)] ):
					def Serialize(o as $(typeName)) as (byte):
						return $(sourceName).$(ser.Name)(o)
						
					def Deserialize( bs as (byte), start as int ) as $(typeName):
						return $(sourceName).$(deser.Name)(bs,start)
					
					Size as int:
						get:
							return $(size)
					Type as Type:
						get:
							return $(typeName)
			|]
			print "almost ${klass.GetType()}"
			cklass = compile(klass, Assembly.LoadFrom("vimp.helper.dll"))
			print "class is ${cklass.GetType()}"
			relations.Add(cklass)
			print "next"


	relations = List[of ISerializer]()
	Relations as IEnumerator[of ISerializer]:
		get:
			return relations
	
	def System.Collections.IEnumerable.GetEnumerator() as IEnumerator:
		return Relations
	
	def GetEnumerator() as IEnumerator[of ISerializer]:
		return Relations
	

static class LinearHelper:

	fieldOffsetAttr = typeof(FieldOffsetAttribute)
	marshalAsAttr = typeof(MarshalAsAttribute)
	linearSerializable = typeof(ISerializable)
	structLayout = typeof(StructLayoutAttribute)
	sequentialLayout = LayoutKind.Sequential
	explicitLayout = LayoutKind.Explicit

	[Getter(Relations)] relations = List[of ISerializer]()
	
	providers = List[of ISerializerProvider]()
	Providers as IEnumerable[of ISerializerProvider]:
		get:
			# TODO, return a ro variant of our list, not the modifiable list
			return providers
		set:
			providers.Clear()
			relations.Clear()
			for f in value:
				providers.Add(f)
				for ser in f:
					relations.Add(ser)
	
	def constructor():
		Providers = ( AutoStaticSerializerProvider(BitConverter) )
	
	def FindSerializer[of T]() as ISerializer[of T]:
		for m in Relations:
			if typeof(T) == m.GetType().GetGenericArguments()[0]:
				return m
		return null
	
	def AddProvider(provider as ISerializerProvider):
		providers.Add(provider)
		for ser in provider:
			relations.Add(ser)

	def GetOffsets(t as Type) as IEnumerator[of int]:
		raise ArgumentException("$(t) is not a linear value type") if not t.IsSubclassOf( ValueType ) 
		
		isSequential = t.Attributes & TypeAttributes.SequentialLayout
		isExplicit = t.Attributes & TypeAttributes.ExplicitLayout
		
		fs = t.GetFields()
		
		if isSequential:
			pos = 0
			
			#for f in fs:
			#	ser = FindSerializer(f.FieldType)
				
			
				
			
		elif isExplicit:
			offset = fs[0].GetCustomAttributes( fieldOffsetAttr, false )[0] as FieldOffsetAttribute
			yield offset.Value
			
			
				
			# primitive
			# record
			# array
			
	
	def GetGenericType():
		pass
		
	#def ConvertItem(ls as ILinearSerializable):
	
	#def Serialize(bs as (byte), t as Type):
	#	for f in t.GetFields():
	
