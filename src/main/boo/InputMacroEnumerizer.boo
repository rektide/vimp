namespace VoodooWarez.Systems.Min

import Boo.Lang.Compiler.MetaProgramming

import C5

import System
import System.IO
import System.Text
import System.Reflection.Emit

import VoodooWarez.Utils



m = MacroEnumerizer()

# prefix to enum name conversion
enm = HashDictionary[of string,string]()
enm["EV"] = "EventTypeEnum"
enm["SYN"] = "SynchronizationEventEnum"
enm["KEY"] = "KeyEnum"
enm["BTN"] = "ButtonEnum"
enm["REL"] = "RelativeAxesEnum"
enm["ABS"] = "AbsoluteAxesEnum"
enm["SW"] = "SwitchEventsEnum"
enm["MSC"] = "MiscEnum"
enm["LED"] = "LedEnum"
enm["REP"] = "AutoRepeatEnum"
enm["SND"] = "SoundEnum"
enm["ID"] = "IdentifierEnum"
enm["BUS"] = "BusEnum"
enm["MT_TOOL"] = "MtToolEnum"
enm["FF_STATUS"] = "FfStatusEnum"
enm["FF_EFFECT"] = "FfEffectEnum"
enm["FF"] = "FfEnum"
m.EnumMap = enm

# camel case members
m.EnumMemberMangler = def(inp as string) as string:
	# CamelCase
	inpv = inp.Split(char('_'))
	sb = StringBuilder()
	for e in inpv:
		sb.Append( char.ToUpper(e[0]) + e[1:].ToLower() )
	outp = sb.ToString()
	# prefix numbers with Num
	try:
		Int32.Parse(outp[0].ToString())
		return "Num"+outp
	except 	FormatException:
		pass
	#
	return outp
	

if argv.Length != 3:
	print "InputMacroEnumerizer namespace input.{h,c} output.dll"
	return
module = m.BuildEnums(argv[1], argv[0])
asmName = argv[2]
asmName = asmName.Substring(0,asmName.LastIndexOf(char('.')))
module.Name = asmName
asmB = compile(module) as AssemblyBuilder
asmB.Save(argv[2])
