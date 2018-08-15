/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.glib;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import stdx.allocator : ISharedAllocator, make;
import devisualization.bindings.gdk.glib.gmain;
import core.atomic;
import core.time;

final class GlibEventLoopSource : EventLoopSource {
    import cf.spew.event_loop.known_implementations;

    private Bindings bindings;

    this(Bindings bindings) shared {
        this.bindings = bindings;
    }

    @property {
        bool onMainThread() shared {
            return true;
        }

        bool onAdditionalThreads() shared {
            return true;
        }

        string description() shared {
            return "Implements support for a glib based event loop iteration. Threaded.";
        }

        EventSource identifier() shared {
            return EventSources.Glib;
        }
    }

    shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
        return alloc.make!(shared(GlibEventLoopSourceRetrieve))(bindings);
    }

    struct Bindings {
        import devisualization.bindings.gdk.glib.gtypes;

    extern (C):
        ///
        GMainContext* function() g_main_context_default;
        ///
        gboolean function(GMainContext* context, gboolean may_block) g_main_context_iteration;
        ////
        GMainContext* function(GMainContext* context) g_main_context_ref;
        ///
        void function(GMainContext* context) g_main_context_unref;
    }
}

final class GlibEventLoopSourceRetrieve : EventLoopSourceRetriever {
    import cf.spew.event_loop.known_implementations;

    private GlibEventLoopSource.Bindings bindings;

    this(shared GlibEventLoopSource.Bindings bindings) shared {
        this.bindings = bindings;
    }

    bool nextEvent(ref Event event) shared {
        // we can't return an event :(
        // wrong event loop model
        event.source = EventSources.Glib;
        // prevents any searching for a consumer (no event actually returned)
        event.type.value = 0;

        if (bindings.g_main_context_default is null || bindings.g_main_context_iteration is null)
            return false;

        // should this be unref'd???
        GMainContext* ctx = bindings.g_main_context_default();
        if (ctx is null)
            return false;

        return bindings.g_main_context_iteration(ctx, false) > 0;
    }

    void handledEvent(ref Event event) shared {
    }

    void unhandledEvent(ref Event event) shared {
    }

    void handledErrorEvent(ref Event event) shared {
    }
    // unsupported, but that is ok, we don't block if we don't get an event!
    void hintTimeout(Duration timeout) shared {
    }
}
