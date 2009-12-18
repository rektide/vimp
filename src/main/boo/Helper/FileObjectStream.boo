namespace VoodooWarez.Systems.Import.Helper

import System
import System.IO

static def Modulo(ref n as int, max as int):
	return (n = n % max)

class ObjectInstantiationEventArgs (EventArgs):
	
	[Property(NewObject)]
	newObject as object
	[Property(FileObjectStream)]
	file as FileObjectStream
	

	def constructor(o,sender as FileObjectStream):
		self.newObject = object
		self.file = sender


class FileObjectStream:
	
	[Property(Serializer)]	
	serializer as ISerializer
	
	[Property(File)]
	file as FileStream
	
	[Property(FileName)]
	fileName as string

	[Property(FileMode)]
	fileMode as System.IO.FileMode = System.IO.FileMode.Open 
	[Property(FileAccess)]
	fileAccess as FileAccess = FileAccess.Read 
	[Property(FileShare)]
	fileShare as FileShare = FileShare.ReadWrite

	[Property(NumBytes)] # byte size
	numBytes as int
	[Property(BufferCapacity)] # units of storage
	bufferCapacity as int = 6
	[Property(MinReuseCount)] # minimum NumBytes to have remaining for buffer reuse
	minReuseCount = 3
	[Getter(BufferLength)] # size of a single buffer, NumBytes * MinReuseCount
	bufferLength as int
	[Property(BufferPosition)] # location within buffer
	bufferPosition as int
	
	[Property(BuffersCount)] # number of buffers
	buffersCount = 4
	[Property(BuffersOffset)] # buffer position
	offset as int = -1
	[Property(Buffers)] # collection of buffers
	buffers as ((byte))
	
	[Property(ReadAsyncResult)]
	readAsyncResult as IAsyncResult
	
	[Property(IsAsync)]
	isAsync as bool = true
	
	[Property(IsRunning)]
	isRunning as bool = false
	
	byteArrayType = array(byte,0).GetType()

	event OnNewObjectInstantiation as callable(ObjectInstantiationEventArgs)

	def constructor(fileName as string, serializer as ISerializer):
		self.serializer = serializer
		self.numBytes = serializer.Size
		self.fileName = fileName
		ReOpenFile()

	def Start():
		offset = (offset + 1) % buffersCount
		DoRead()
	
	protected def DoRead():
		length = bufferLength - bufferPosition
		if isAsync:
			readAsyncResult = file.BeginRead(buffers[offset],bufferPosition,length,ReadCallback,self)
		else:
			raise ArgumentException("Presently only IsAsync mode is supported")
		
	def ReOpenFile():
		self.file.Dispose() if self.file
		self.file = FileStream(fileName,fileMode,fileAccess,fileShare,bufferLength,isAsync)
	
	def ReInitBuffers():
		# set bufferLength
		bufferLength = numBytes * bufferCapacity
		
		# regenerate buffers
		buffers = array(byteArrayType,buffersCount)
		for i in range(buffersCount):
			buffers[i] = array(byte,bufferLength)
		
		# reset positions
		buffersOffset = -1
		bufferPosition = 0
		
	static def ReadCallback(ar as IAsyncResult):
		fsm = ar.AsyncState as FileObjectStream
		count = fsm.File.EndRead(ar)
	
		# process awaiting bytes:
		residual = fsm.BufferPosition % fsm.NumBytes # already filled bytes to use
		countDown = count + residual # number of bytes remaining in stream
		start = fsm.BufferPosition - residual # starting place including prefill
		while countDown >= fsm.numBytes:
			obj= fsm.Serializer.Deserialize(fsm.Buffers[fsm.BuffersOffset],start)
			objEvent = ObjectInstantiationEventArgs(obj,fsm)
			fsm.OnNewObjectInstantiation(objEvent)
			countDown -= fsm.NumBytes
			start += fsm.NumBytes
		fsm.BufferPosition += count # advance to end
	
		remaining = fsm.BufferLength - fsm.BufferPosition
		reuseMinimum = fsm.NumBytes * fsm.MinReuseCount
		if remaining >= reuseMinimum:
			# sufficient remaining capacity to reuse current buffer
			pass
		else:
			# find next stack
			lastOffset= fsm.BuffersOffset
			newOffset= fsm.BuffersOffset = (fsm.BuffersOffset + 1) % fsm.BuffersCount
			
			# shuffle any remainder
			for i in range(countDown):
				fsm.Buffers[newOffset][i] = fsm.Buffers[lastOffset][fsm.BufferPosition-i]
			
			# Go to next buffer
			fsm.BufferPosition = countDown
			#fsm.BuffersOffset already set during newOffset
		
		# Continue running
		fsm.DoRead() if fsm.IsRunning
