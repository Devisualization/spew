/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.epoll;
version(linux):
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import stdx.allocator : ISharedAllocator, make, dispose, makeArray, expandArray, shrinkArray, processAllocator;
import core.thread;

final class EpollEventLoopSource : EventLoopSource {
    import cf.spew.event_loop.known_implementations;
    import core.sys.posix.stdio;
    import core.stdc.stdio;

    @property {
        bool onMainThread() shared { return true; }
        bool onAdditionalThreads() shared { return true; }
        string description() shared { return "Implements support for FILE* polling via epoll. Singleton but threaded."; }
        EventSource identifier() shared { return EventSources.Epoll; }
    }

    shared(EpollPerThreadRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
        return getRetriever(Thread.getThis().id, alloc);
    }

    //

    void registerFD(int fd, void delegate(int events) callback) shared {
        if (callback is null) return;
        getRetriever(Thread.getThis().id, processAllocator()).addFD(fd, callback);
    }

    void unregisterFD(int fd) shared {
        getRetriever(Thread.getThis().id, processAllocator()).removeFD(fd);
    }

    static shared(EpollEventLoopSource) instance() {
        static auto self = new shared EpollEventLoopSource;
        return self;
    }
}

private {
    shared(EpollPerThreadRetriever) retrievers;

    static ~this() {
        // deregister this thread
        ThreadID tid = Thread.getThis().id;
        shared(EpollPerThreadRetriever) previous, instance = retrievers;

        while(instance !is null) {
            shared(EpollPerThreadRetriever) next = instance.next;

            if (instance.threadId == tid) {
                instance.alloc.dispose(instance);

                if (previous is null) {
                    retrievers = next;http://man7.org/linux/man-pages/man2/close.2.html
                } else {
                    previous.next = next;
                }
            } else
                previous = instance;

            instance = next;
        }

    }

    shared(EpollPerThreadRetriever) getRetriever(ThreadID tid, shared(ISharedAllocator) alloc) {
        shared(EpollPerThreadRetriever) instance = retrievers;

        while(instance !is null) {
            if (instance.threadId == tid) {
                return instance;
            }
            instance = instance.next;
        }

        if (alloc is null) {
            return null;
        } else {
            shared(EpollPerThreadRetriever) temp = alloc.make!(shared(EpollPerThreadRetriever))(tid, alloc);

            if (instance is null) {
                retrievers = temp;
            } else {
                instance.next = temp;
            }

            return temp;
        }
    }
}

/// To get a specific allocator for this thread, call nextEventGenerator before the event loop does.
final class EpollPerThreadRetriever : EventLoopSourceRetriever {
    private {
        import core.sys.linux.epoll;
        import core.sys.posix.unistd : close;
        import core.sys.linux.errno : EINTR;
        import core.atomic : atomicOp;

        shared(EpollPerThreadRetriever) next;
        ThreadID threadId;

        size_t countFd;
        int[] fds;
        void delegate(int events)[] callbacks;
        shared(ISharedAllocator) alloc;

        int threadPoller;
        epoll_event[] eventBuffer;
    }

    //

    ~this() {
        if (countFd == 0) return;

        alloc.dispose(fds);
        alloc.dispose(callbacks);

        // http://man7.org/linux/man-pages/man2/close.2.html
        close(threadPoller);
        alloc.dispose(eventBuffer);
    }

    void addFD(int fd, void delegate(int) callback) shared {
        synchronized {
            foreach(i, ref c; callbacks) {
                if (c !is null && fds[i] == fd) {
                    c = null;
                    atomicOp!"-="(countFd, 1);
                    return;
                }
            }

            if (countFd == fds.length) {
                if (countFd == 0) {
                    fds = alloc.makeArray!(shared(int))(8);
                    callbacks = cast(shared)alloc.makeArray!(void delegate(int))(8);
                } else {
                    int[] fds2 = cast(int[])fds;
                    alloc.expandArray(fds2, 16);
                    fds = cast(shared)fds2;

                    auto callbacks2 = cast(void delegate(int)[])callbacks;
                    alloc.expandArray(callbacks2, 16);
                    callbacks = cast(shared)callbacks2;
                }
            }

            foreach(uint i, ref c; callbacks) {
                if (c is null) {
                    c = callback;
                    fds[i] = fd;
                    atomicOp!"+="(countFd, 1);

                    // http://man7.org/linux/man-pages/man2/epoll_ctl.2.html
                    epoll_event ev;
                    ev.events = EPOLLIN | EPOLLOUT | EPOLLRDHUP | EPOLLPRI | EPOLLERR | EPOLLHUP;
                    ev.data.u32 = i;
                    epoll_ctl(threadPoller, EPOLL_CTL_ADD, fd, &ev);
                    return;
                }
            }
        }

        assert(0);
    }


    void removeFD(int fd) shared {
        synchronized {
            foreach(i, ref c; callbacks) {
                if (c !is null && fds[i] == fd) {
                    c = null;
                    atomicOp!"-="(countFd, 1);
                    return;
                }
            }

            // http://man7.org/linux/man-pages/man2/epoll_ctl.2.html
            epoll_ctl(threadPoller, EPOLL_CTL_DEL, fd, null);
        }
    }

    //

    this(ThreadID tid, shared(ISharedAllocator) alloc) shared {
        this.threadId = tid;
        this.alloc = alloc;

        // http://man7.org/linux/man-pages/man2/epoll_create.2.html
        // epoll = thread safe
        threadPoller = epoll_create1(0);
    }

    bool nextEvent(ref Event event) shared {
        import std.math : sqrt;
        synchronized {
            if (fds.length == 0)
                return false;

            int bufferlen = cast(int)(2^^sqrt(cast(float)fds.length));
            if (bufferlen != eventBuffer.length) {
                if (eventBuffer !is null) {
                    alloc.dispose(cast(epoll_event[])eventBuffer);
                }

                eventBuffer = cast(shared)alloc.makeArray!(epoll_event)(bufferlen);
            }


            // http://man7.org/linux/man-pages/man2/epoll_wait.2.html
            int count = epoll_wait(threadPoller, cast(epoll_event*)eventBuffer.ptr, bufferlen, 0);

            if (count < 0) {
                if (count == EINTR) {
                    // ok, timeout
                }
            } else {
                foreach(ev; eventBuffer[0 .. count]) {
                    // call handles callbacks
                    if (ev.data.u32 >= callbacks.length) continue;

                    auto callback = callbacks[ev.data.u32];
                    if (callback !is null)
                        callback(ev.events);
                }
            }
        }
        // doesn't need to be often, just has to happen
        // after all, this isn't about high performance polling!
        return false;
    }

    void handledEvent(ref Event event) shared {}
    void unhandledEvent(ref Event event) shared {}
    void handledErrorEvent(ref Event event) shared {}
    void hintTimeout(Duration timeout) shared {}
}


