module cf.spew.implementation.instance.streams.base;
import cf.spew.instance : Management_Streams;
import cf.spew.streams;
import std.socket : Address;
import stdx.allocator : ISharedAllocator;

abstract class StreamsInstance : Management_Streams {
    shared(ISharedAllocator) allocator;

    ~this() {
        (cast(shared)this).forceCloseAll();
    }

    this(shared(ISharedAllocator) allocator) shared {
        this.allocator = allocator;
    }

    void forceCloseAll() shared {
        import cf.spew.implementation.streams.base : StreamPoint;

        StreamPoint.closeAllInstances();
    }
}
