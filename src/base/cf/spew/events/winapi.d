module cf.spew.events.winapi;
version(Windows):

import cf.spew.events.defs;
import core.sys.windows.windows : MSG;

enum WinAPI_Events_Types {
	Unknown = EventType.from("wapi", "uknw"),
}

union WinAPI_Events {
	MSG raw;
}