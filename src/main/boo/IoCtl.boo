namespace VoodooWarez.Systems

#import Microsoft.Win32.SafeHandles

import System
import System.Runtime.InteropServices

[Flags]
public enum IocAccessMode:
	None = 0
	Write = 1
	Read = 2

[StructLayout(LayoutKind.Explicit, Size: 4)]
struct IoCtl[of T]:
	
	[DllImport("libc.so", EntryPoint: "ioctl")] 
	protected static def IoCtlNone([In] fd as int, [In] command as int, [In] obj as T):
		pass
	
	[DllImport("libc.so", EntryPoint: "ioctl")] 
	protected static def IoCtlRead([In] fd as int, [In] command as int, [Out] obj as T):
		pass

	[DllImport("libc.so", EntryPoint: "ioctl")] 
	protected static def IoCtlWrite([In] fd as int, [In] command as int, [In] obj as T):
		pass
	
	[DllImport("libc.so", EntryPoint: "ioctl")] 
	protected static def IoCtlBoth([In] fd as int, command as int, [In,Out] obj as T):
		pass

	[FieldOffset(0)] [Property(Command)] command as byte
	[FieldOffset(1)] [Property(Type)] type as byte
	[FieldOffset(2)] size as ushort

	def constructor(command as byte, type as byte, accessMode as IocAccessMode):
		size = 0
		try:
			size = Marshal.SizeOf(T)
		except:
			pass
		self(command,type,size,accessMode)

	def constructor(command as byte, type as byte, size as ushort, accessMode as IocAccessMode):
		self.command = command
		self.type = type
		self.size = size
		AccessMode = accessMode
	
	FullCommand as ushort:
		get:
			return type << 8 | command
		set:
			command = value & 0xFF
			type = value >> 8
	
	AccessMode as IocAccessMode:
		get:
			return Enum.ToObject(IocAccessMode,size >> 14)
		set:
			size = size & 0x3FFF | cast(ushort,value) << 14

	ParameterSize as ushort:
		get:
			return size & 0x3FFF
		set:	
			size = size & 0xC000 | value & 0x3FFF

	def Run(handle as int, obj as T) as int:
		raise ArgumentException("Invalid handle") if handle < 1
		mode = AccessMode
		if mode == IocAccessMode.Read:
			IoCtlRead(handle, command, obj)
		elif mode == IocAccessMode.Read | IocAccessMode.Write:
			IoCtlBoth(handle, command, obj)
		elif mode == IocAccessMode.Write:
			IoCtlWrite(handle, command, obj)
		elif mode == IocAccessMode.None:
			IoCtlNone(handle, command, obj)
		else:
			raise ArgumentException("Invalid AccessMode")
