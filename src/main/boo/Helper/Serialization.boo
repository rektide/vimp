namespace VoodooWarez.Systems.Import.Helper

import Boo.Lang.Compiler.MetaProgramming
import Boo.Lang.Compiler.Ast

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
	def Deserialize(o as (byte), start as int) as object:
		pass
	Size as int:
		get
	Type as Type:
		get

interface IGenericSerializer[of T](ISerializer):
	def GenericSerialize(o as T) as (byte):
		pass
	def GenericDeserialize(o as (byte), start as int) as T:
		pass

interface ISerializerProvider:
	Serializers as IEnumerable[of ISerializer]:
		get


class StructSerializerProvider (ISerializerProvider):
	
	serializers as (ISerializer)
	Serializers as IEnumerable[of ISerializer]:
		get:
			return serializers
		set:
			serializers = array(ISerializer,value)
	
	static structSerializer as Type
	static iSerializable as Type
	
	static def constructor():
		structSerializer = Type.GetType("VoodooWarez.Systems.Import.Helper.StructSerializer`1")
		iSerializable = Type.GetType("VoodooWarez.Systems.Import.Helper.ISerializable")
	
	def constructor(serializant as Type):
		
		# validate input
		found = false
		for i in serializant.GetInterfaces():
			found = true if i == iSerializable
		raise ArgumentException("Not a ISerializable class") if not found
	
		# build ISerializer for ISerialable	
		t = structSerializer.MakeGenericType(serializant)
		serializer = Activator.CreateInstance(t) as ISerializer
		
		# install
		serializers = array(ISerializer,(serializer,))
	
class StructSerializer[of T(ISerializable,constructor,class)] (IGenericSerializer[of T], NotSupportedSerializer):

	Type as Type:
		get:
			return TargetType
	
	size as int
	Size as int:
		get:
			return size
	
	def constructor():
		super(typeof(T))
		size = Marshal.SizeOf(typeof(T))
		
	def GenericSerialize(o as T) as (byte):
		return o.Serialize()
		
	def GenericDeserialize(bs as (byte), start as int) as T:
		# instantiating generic parameters not yet supported
		o = Activator.CreateInstance(typeof(T)) 
		# kludge around boo/generic-dodginess with a duck
		(o as duck).Deserialize(bs,start)
		return o as T
	
	def Serialize(o) as (byte):
		AssertType(o)
		return (o as T).Serialize()
	
	def Deserialize(bs as (byte), start as int) as object:
		o = Activator.CreateInstance(typeof(T))
		(o as duck).Deserialize(bs,start)
		return o
		


abstract class NotSupportedSerializer(ISerializer):
	
	target as Type
	isInterface as bool
	
	TargetType as Type:
		get:
			return target
		set:
			target = value
			isInterface = value.IsInterface
			
	def constructor(target as Type):
		self.TargetType = target
	
	protected def AssertType(candidate):
		oType = candidate.GetType()
		oType = candidate if oType == typeof(Type)
		raise ArgumentException("Not supported type ${oType}") if not IsOfTargetType(oType)
	
	protected def IsOfTargetType(candidate as Type):
		return true if candidate == target
		if isInterface:
			interfaces = candidate.GetInterfaces()
			for i in interfaces:
				return true if i == target
		base = candidate.BaseType
		while(base):
			return true if base == target
			base = candidate.BaseType
		return false
	
class AutoStaticSerializerProvider (ISerializerProvider):

	source as Type
	toBytePattern as regex
	bytesType = typeof((byte))
	intType = typeof(int)
	
	providerInstance as int # this classes' assigned instanceIter
	relationInstance as int # enumeration of relations provided by this provider
	
	static instanceIter = 0
	
	serializers = List[of ISerializer]()
	Serializers as IEnumerable[of ISerializer]:
		get:
			return serializers

	vimpHelperAssembly as Assembly
	protected VimpHelperAssembly as Assembly:
		get:
			return vimpHelperAssembly if vimpHelperAssembly
			for asm in AppDomain.CurrentDomain.GetAssemblies():
				for mod in asm.GetModules():
					vimpHelperAssembly = asm if mod.Name == "vimp.helper.dll"
			raise Exception("vimp.helper.dll not found") if not vimpHelperAssembly
			return vimpHelperAssembly
			

	def constructor(source as Type):
		self(source, /GetBytes/)
	
	def constructor(source as Type, toBytePattern as regex):
		self.source = source
		self.toBytePattern = toBytePattern
		self.providerInstance = Interlocked.Increment(instanceIter)

		genMod = [|
			namespace VoodooWarez.Systems.Import.Helper.Generated
			
			import VoodooWarez.Systems.Import.Helper
			import System
		|]
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
			for m as MethodInfo in methods:
				continue if not m.IsStatic
				continue if not m.ReturnType == targetType 
				dsprms = m.GetParameters()
				continue if not dsprms.Length == 2
				continue if not dsprms[0].ParameterType == bytesType
				continue if not dsprms[1].ParameterType == intType
				deser = m
				break
			continue if not deser
			
			# find size via a run on a default instance
			instance = Activator.CreateInstance(targetType)
			bytes = ser.Invoke(null, (instance,) ) as (byte)
			size = bytes.Length
		
			# retrieve names
			typeName = targetType.FullName
			typeRef = ReferenceExpression.Lift(typeName)
			sourceName = source.FullName
			sourceRef = ReferenceExpression.Lift(sourceName)
			klassName = "_AutoStaticRelation_${providerInstance}_${++relationInstance}"
			
			klass = [|
				class $(klassName) ( IGenericSerializer[of $(typeName)] ):
					
					def Serialize(o) as (byte):
						return $(sourceRef).$(ser.Name)(cast($typeName,o))
					
					def GenericSerialize(o as $(typeName)) as (byte):
						return $(sourceRef).$(ser.Name)(o)
						
					def Deserialize( bs as (byte), start as int) as object:
						return $(sourceRef).$(deser.Name)(bs,start)
					
					def GenericDeserialize( bs as (byte), start as int ) as $(typeName):
						return $(sourceRef).$(deser.Name)(bs,start)
					
					Size as int:
						get:
							return $(size)
					Type as Type:
						get:
							return typeof($(typeRef))
			|]
			genMod.Members.Add(klass)
		
		asm= compile(genMod, VimpHelperAssembly, Assembly.Load("System"))
		for serClass in asm.GetTypes():
			serInstance = Activator.CreateInstance(serClass)
			serializers.Add(serInstance)
	
static class LinearHelper:

	fieldOffsetAttr = typeof(FieldOffsetAttribute)
	marshalAsAttr = typeof(MarshalAsAttribute)
	linearSerializable = typeof(ISerializable)
	structLayout = typeof(StructLayoutAttribute)
	sequentialLayout = LayoutKind.Sequential
	explicitLayout = LayoutKind.Explicit

	[Getter(Serializers)] serializers = List[of ISerializer]()
	
	providers = List[of ISerializerProvider]()
	Providers as IEnumerable[of ISerializerProvider]:
		get:
			# TODO, return a ro variant of our list, not the modifiable list
			return providers
		set:
			providers.Clear()
			serializers.Clear()
			for f in value:
				providers.Add(f)
				for ser in f.Serializers:
					serializers.Add(ser)
	
	def constructor():
		Providers = ( AutoStaticSerializerProvider(BitConverter) as ISerializerProvider, )
	
	def FindSerializer[of T]() as IGenericSerializer[of T]:
		return FindSerializer(typeof(T)) as IGenericSerializer[of T]

	def FindSerializer(t as Type) as ISerializer:
		for s in Serializers:
			i = s.GetType().GetInterface("IGenericSerializer`1")
			continue if not i
			return s if t == i.GetGenericArguments()[0]
		
	def AddProvider(provider as ISerializerProvider):
		providers.Add(provider)
		for ser in provider.Serializers:
			serializers.Add(ser)

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


