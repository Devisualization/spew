module cf.spew.implementation.instance.eventloop;
import cf.spew.event_loop.defs : IEventLoopManager;
import cf.spew.implementation.manager;
import cf.spew.instance : Management_EventLoop;
import stdx.allocator : ISharedAllocator, make, dispose;

final class EventLoopWrapper : Management_EventLoop {
    this(shared(ISharedAllocator) allocator) shared {
        this.allocator = allocator;
        _manager = allocator.make!(shared(EventLoopManager_Impl));
    }

    ~this() {
        allocator.dispose(_manager);
    }

    shared(ISharedAllocator) allocator;
    shared(IEventLoopManager) _manager;

    bool isRunningOnMainThread() shared {
        return _manager.runningOnMainThread;
    }

    bool isRunning() shared {
        return _manager.runningOnMainThread || _manager.runningOnAuxillaryThreads;
    }

    void stopCurrentThread() shared {
        _manager.runningOnThreadFor;
    }

    void stopAllThreads() shared {
        _manager.stopAllThreads;
    }

    void execute() shared {
        _manager.execute;
    }

    @property shared(IEventLoopManager) manager() shared {
        return _manager;
    }
}
