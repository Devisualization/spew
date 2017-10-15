module cf.spew.event_loop.wells.libuv;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import std.experimental.allocator : ISharedAllocator, make;
import devisualization.bindings.libuv.uv;
import core.time;

uv_loop_t* getThreadLoop_UV() {
	import devisualization.bindings.libuv.loader;

	if (libuvLoader is LibUVLoader.init)
		libuvLoader = LibUVLoader(null);
	if (uvLoop.data is null)
		performInit;

	return &uvLoop;
}

private {
	uv_loop_t uvLoop;
	shared LibUVEventLoopSource uvLoopSource = new shared LibUVEventLoopSource;

	static this() {
		getThreadLoop_UV();
	}

	static ~this() {
		if (uvLoop.data !is null) {
			uv_stop(&uvLoop);
			uv_loop_close(&uvLoop);
		}
	}

	void performInit() {
		uv_loop_init(&uvLoop);
		uvLoop.data = cast(void*)&uvLoopSource;
	}
}

final class LibUVEventLoopSource : EventLoopSource {
	import cf.spew.event_loop.known_implementations;
	
	@property {
		bool onMainThread() shared { return true; }
		bool onAdditionalThreads() shared { return true; }
		string description() shared { return "Implements support for a LibUV based event loop iteration. Singleton but threaded."; }
		EventSource identifier() shared { return EventSources.LibUV; }
	}
	
	shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
		if (uvLoop.data is null)
			performInit;
		return alloc.make!(shared(LibUVEventLoopSourceRetrieve));
	}

	static shared(LibUVEventLoopSource) instance() { return uvLoopSource; }
}

final class LibUVEventLoopSourceRetrieve : EventLoopSourceRetriever {
	import cf.spew.event_loop.known_implementations;
	
	bool nextEvent(ref Event event) shared {
		// we can't return an event :(
		// wrong event loop model
		event.source = EventSources.LibUV;
		// prevents any searching for a consumer (no event actually returned)
		event.type.value = 0;
		// tells the manager if there are more events
		uv_run(&uvLoop, uv_run_mode.UV_RUN_NOWAIT);
		return false;
	}
	
	void handledEvent(ref Event event) shared {}
	void unhandledEvent(ref Event event) shared {}
	void handledErrorEvent(ref Event event) shared {}
	// unsupported, but that is ok, we don't block if we don't get an event!
	void hintTimeout(Duration timeout) shared {}
}