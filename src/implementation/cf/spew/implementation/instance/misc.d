module cf.spew.implementation.instance.misc;
import cf.spew.implementation.instance.state : timerToIdMapper;
import cf.spew.instance : Management_Miscellaneous;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, ISharedAllocator, make, theAllocator;

final class Miscellaneous_Instance : Management_Miscellaneous {
    import cf.spew.miscellaneous;
    import std.experimental.containers.map;
    import core.time : Duration;

    this(shared(ISharedAllocator) alloc) shared {
        timerToIdMapper = SharedMap!(size_t, ITimer)(alloc);
    }

    managed!ITimer createTimer(Duration timeout, bool hintSystemWait = true,
            IAllocator alloc = theAllocator()) shared {
        ITimer ret;

        if (hintSystemWait) {
            version (Windows) {
                import cf.spew.implementation.misc.timer.winapi;
                ret = alloc.make!WinAPITimer(timeout);
            }
        }

        if (ret is null) {
            import cf.spew.implementation.misc.timer.libuv;
            import devisualization.bindings.libuv : libuv;

            if (libuv !is null && libuv.uv_timer_init !is null) {
                ret = alloc.make!LibUVTimer(timeout);
            }
        }

        if (ret is null)
            return managed!ITimer.init;
        else
            return managed!ITimer(ret, managers(), alloc);
    }

    managed!IFileSystemWatcher createFileSystemWatcher(string path, IAllocator alloc = theAllocator()) shared {
        IFileSystemWatcher ret;

        import cf.spew.implementation.misc.filewatcher.libuv;
        ret = alloc.make!LibUVFileSystemWatcher(path, alloc);

        return managed!IFileSystemWatcher(ret, managers(), alloc);
    }
}
