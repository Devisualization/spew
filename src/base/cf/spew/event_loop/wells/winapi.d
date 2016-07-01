module cf.spew.event_loop.wells.winapi;
version(Windows):

import cf.spew.event_loop.defs;
import cf.spew.event_loop.known_implementations;
import cf.spew.events.defs;

final class WinAPI_EventLoop_Source : EventLoopSource {
	@property {
		bool onMainThread() { return true; }
		bool onAdditionalThreads() { return true; }

		EventSource identifier() { return EventSources.WinAPI; }
	}

	bool nextEvent(ref Event event) {
		return false;
	}
}