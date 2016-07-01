module cf.spew.event_loop.known_implementations;
import cf.spew.events.defs : EventSource;

/**
 * 
 */
enum EventSources {
	///
	WinAPI = EventSource.from("winapi"),
	///
	X11 = EventSource.from("x11"),
	///
	Cocoa = EventSource.from("cocoa")
}