module cf.spew.events.winapi;
version(Windows):

import cf.spew.events.defs;
import core.sys.windows.windows;

enum WinAPI_Events_Types {
	____ = EventType.from("wapi", "...."),
}

struct WinAPI_Events {
	int ____;
}