/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.x11;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import stdx.allocator : ISharedAllocator, make;
import devisualization.bindings.x11;

Display* x11Display() {
	if (display is null)
		performInit();
	assert(display !is null);
	return display;
}

private {
	Display* display;
	shared X11EventLoopSource instanceloopSource = new shared X11EventLoopSource;

	void performInit() {
		if (x11Loader is X11Loader.init) {
			x11Loader = X11Loader(null);
		}

		assert(x11.XOpenDisplay !is null);
		assert(x11.XCloseDisplay !is null);
		assert(x11.XPending !is null);
		assert(x11.XNextEvent !is null);

		display = x11.XOpenDisplay(null);
	}

	static ~this() {
		if (display !is null)
			x11.XCloseDisplay(display);
	}
}

final class X11EventLoopSource : EventLoopSource {
	import cf.spew.event_loop.known_implementations;

	@property {
		bool onMainThread() shared { return true; }
		bool onAdditionalThreads() shared { return true; }
		string description() shared { return "Implements support for a X11 based event loop iteration. Singleton but threaded."; }
		EventSource identifier() shared { return EventSources.X11; }
	}

	shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
		if (display is null)
			performInit();

		return alloc.make!(shared(X11EventLoopSourceRetrieve));
	}

	static shared(X11EventLoopSource) instance() { return instanceloopSource; }
}

final class X11EventLoopSourceRetrieve : EventLoopSourceRetriever {
	import cf.spew.event_loop.known_implementations;
	import core.time : dur, Duration;

	bool nextEvent(ref Event event) shared {
		event.source = EventSources.X11;
		// prevents any searching for a consumer (no event actually returned)
		event.type.value = 0;

		int pending = x11.XPending(display);
		if (pending > 0) {
			XEvent x11Event;
			x11.XNextEvent(display, &x11Event);
			processEvent(x11Event, event);
		}

		return pending > 0;
	}

	void handledEvent(ref Event event) shared {}
	void unhandledEvent(ref Event event) shared {}
	void handledErrorEvent(ref Event event) shared {}
	void hintTimeout(Duration timeout) shared {}
}

private {
	void processEvent(ref XEvent x11Event, ref Event event) {

	}
}
