/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.libuv;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import stdx.allocator : ISharedAllocator, make;
import devisualization.bindings.libuv;
import core.time;
import core.atomic;

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
    uv_timer_t uvLoopTimeout;
    bool uvLoopInitialized;

    shared LibUVEventLoopSource uvLoopSource = new shared LibUVEventLoopSource;

    static this() {
        getThreadLoop_UV();
    }

    static ~this() {
        if (uvLoop.data !is null) {
            if (uvLoopInitialized)
                libuv.uv_close(cast(uv_handle_t*)&uvLoopTimeout, null);

            libuv.uv_stop(&uvLoop);
            libuv.uv_loop_close(&uvLoop);
        }
    }

    void performInit() {
        libuv.uv_loop_init(&uvLoop);
        uvLoop.data = cast(void*)&uvLoopSource;
    }
}

final class LibUVEventLoopSource : EventLoopSource {
    import cf.spew.event_loop.known_implementations;

    @property {
        bool onMainThread() shared {
            return true;
        }

        bool onAdditionalThreads() shared {
            return true;
        }

        string description() shared {
            return "Implements support for a LibUV based event loop iteration. Singleton but threaded.";
        }

        EventSource identifier() shared {
            return EventSources.LibUV;
        }
    }

    shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
        if (uvLoop.data is null)
            performInit;
        return alloc.make!(shared(LibUVEventLoopSourceRetrieve));
    }

    static shared(LibUVEventLoopSource) instance() {
        return uvLoopSource;
    }
}

final class LibUVEventLoopSourceRetrieve : EventLoopSourceRetriever {
    import cf.spew.event_loop.known_implementations;
    import core.time : dur;

    Duration timeout = dur!"seconds"(1);

    bool nextEvent(ref Event event) shared {
        // we can't return an event :(
        // wrong event loop model
        event.source = EventSources.LibUV;
        // prevents any searching for a consumer (no event actually returned)
        event.type.value = 0;

        // empty event loop, important if no e.g. sockets are used.
        if (libuv.uv_loop_alive(&uvLoop) == 0)
            return false;
        else if (!uvLoopInitialized) {
            uvLoopInitialized = true;
            libuv.uv_timer_init(&uvLoop, &uvLoopTimeout);
        }

        // setup a timer so we can find out if we have gone beyond what we are allowed.
        ulong timeoutms = cast(ulong)atomicLoad(timeout).total!"msecs" / 2;

        if (timeoutms < int.max) {
            timeoutms++;
            uvLoopTimeout.data = &uvLoop;
            libuv.uv_timer_start(&uvLoopTimeout, &uvLoopTimerCB, timeoutms, timeoutms);
        }

        // tells the manager if there are more events
        libuv.uv_run(&uvLoop, uv_run_mode.UV_RUN_ONCE);

        if (timeoutms < int.max)
            libuv.uv_timer_stop(&uvLoopTimeout);

        return uvLoopTimeout.data !is null;
    }

    void handledEvent(ref Event event) shared {
    }

    void unhandledEvent(ref Event event) shared {
    }

    void handledErrorEvent(ref Event event) shared {
    }

    void hintTimeout(Duration timeout) shared {
        this.timeout = timeout;
    }
}

extern (C) {
    void uvLoopTimerCB(uv_timer_t* timer) {
        if (timer.data !is null) {
            auto loop = cast(uv_loop_t*)timer.data;
            timer.data = null;
            libuv.uv_stop(loop);
        }
    }
}
