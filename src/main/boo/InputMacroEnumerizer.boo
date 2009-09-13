namespace VoodooWarez.Min

import C5

import System
import System.IO
import System.Text

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
enm["FF"] = "FfEffectEnum"
m.EnumNameMangler = def(inp as string):
	outp as string
	try:
		return enm[inp]
	except:
		pass
	return inp

# camel case members
m.EnumMemberMangler = def(inp as string):
	inpv = inp.Split(char('_'))
	sb = StringBuilder()
	for e in inpv:
		sb.Append( char.ToUpper(e[0]) + e[1:].ToLower() )
	
	
m.BuildEnums(argv[1], argv[0])
