///
module cf.spew.event_loop.known_implementations;
import cf.spew.events.defs : EventSource;

/**
 * 
 */
enum EventSources {
	///
	Prefix = EventSource.from("s_"),

	///
	WinAPI = EventSource.from("s_winapi"),
	///
	X11 = EventSource.from("s_x11"),
	///
	Cocoa = EventSource.from("s_cocoa")
}