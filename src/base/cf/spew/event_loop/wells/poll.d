/**
 * Posix poll, Linux epoll FILE* polling well.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.poll;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import stdx.allocator : ISharedAllocator, make, dispose, makeArray, expandArray, shrinkArray, processAllocator;
import core.thread;
version(Posix):

///
final class PollEventLoopSource : EventLoopSource {
    import cf.spew.event_loop.known_implementations;
    import core.sys.posix.stdio;
    import core.stdc.stdio;

    @property {
        ///
        bool onMainThread() shared { return true; }
        ///
        bool onAdditionalThreads() shared { return true; }
        ///
        string description() shared { return "Implements support for FILE* polling via (e)poll. Singleton but threaded."; }
        ///
        EventSource identifier() shared { return EventSources.Epoll; }
    }

    /// To get a specific allocator for this thread, call nextEventGenerator before the event loop does.
    shared(PerThreadRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
        return getRetriever(Thread.getThis().id, alloc);
    }

    //

    ///
    void registerFD(int fd, void delegate(int events) callback) shared {
        if (callback is null) return;
        getRetriever(Thread.getThis().id, processAllocator()).addFD(fd, callback);
    }

    ///
    void unregisterFD(int fd) shared {
        getRetriever(Thread.getThis().id, processAllocator()).removeFD(fd);
    }

    ///
    static shared(PollEventLoopSource) instance() {
        static auto self = new shared PollEventLoopSource;
        return self;
    }
}

private {
    version(linux) {
        alias PerThreadRetriever = EpollPerThreadRetriever;
    } else {
        alias PerThreadRetriever = PollPerThreadRetriever;
    }

    shared(PerThreadRetriever) retrievers;

    static ~this() {
        // deregister this thread
        ThreadID tid = Thread.getThis().id;
        shared(PerThreadRetriever) previous, instance = retrievers;

        while(instance !is null) {
            shared(PerThreadRetriever) next = instance.next;

            if (instance.threadId == tid) {
                instance.alloc.dispose(instance);

                if (previous is null) {
                    retrievers = next;
                } else {
                    previous.next = next;
                }
            } else
                previous = instance;

            instance = next;
        }

    }

    shared(PerThreadRetriever) getRetriever(ThreadID tid, shared(ISharedAllocator) alloc) {
        shared(PerThreadRetriever) instance = retrievers;

        while(instance !is null) {
            if (instance.threadId == tid) {
                return instance;
            }
            instance = instance.next;
        }

        if (alloc is null) {
            return null;
        } else {
            shared(PerThreadRetriever) temp = alloc.make!(shared(PerThreadRetriever))(tid, alloc);

            if (instance is null) {
                retrievers = temp;
            } else {
                instance.next = temp;
            }

            return temp;
        }
    }
}

version(linux) {
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
} else {
    final class PollPerThreadRetriever : EventLoopSourceRetriever {
        private {
            import core.sys.posix.poll;
            import core.sys.posix.unistd : close;
            import core.stdc.errno;
            import core.atomic : atomicOp;

            shared(PollPerThreadRetriever) next;
            ThreadID threadId;

            void delegate(int events)[] callbacks;
            shared(ISharedAllocator) alloc;

            size_t countFd;
            pollfd[] pollfds;
        }

        //

        ~this() {
            if (countFd == 0) return;

            alloc.dispose(callbacks);
            alloc.dispose(pollfds);
        }

        void addFD(int fd, void delegate(int) callback) shared {
            synchronized {
                foreach(i, ref c; callbacks) {
                    if (c !is null && pollfds[i].fd == fd) {
                        if (countFd > 1 && i+1 < countFd) {
                            pollfds[i] = pollfds[countFd-1];
                            c = callbacks[countFd-1];
                        } else {
                            c = null;
                        }

                        atomicOp!"-="(countFd, 1);
                        return;
                    }
                }

                if (countFd == pollfds.length) {
                    if (countFd == 0) {
                        pollfds = alloc.makeArray!(shared(pollfd))(8);
                        callbacks = cast(shared)alloc.makeArray!(void delegate(int))(8);
                    } else {
                        pollfd[] pollfds2 = cast(pollfd[])pollfds;
                        alloc.expandArray(pollfds2, 16);
                        pollfds = cast(shared)pollfds2;

                        auto callbacks2 = cast(void delegate(int)[])callbacks;
                        alloc.expandArray(callbacks2, 16);
                        callbacks = cast(shared)callbacks2;
                    }
                }

                foreach(uint i, ref c; callbacks) {
                    if (c is null) {
                        c = callback;
                        pollfds[i].fd = fd;
                        atomicOp!"+="(countFd, 1);
                        pollfds[i].events = POLLIN | POLLOUT | POLLPRI | POLLERR | POLLHUP;
                        return;
                    }
                }
            }

            assert(0);
        }


        void removeFD(int fd) shared {
            synchronized {
                foreach(i, ref c; callbacks) {
                    if (c !is null && pollfds[i].fd == fd) {
                        if (countFd > 1 && i+1 < countFd) {
                            pollfds[i] = pollfds[countFd-1];
                            c = callbacks[countFd-1];
                        } else {
                            c = null;
                        }

                        atomicOp!"-="(countFd, 1);
                        return;
                    }
                }
            }
        }

        //

        this(ThreadID tid, shared(ISharedAllocator) alloc) shared {
            this.threadId = tid;
            this.alloc = alloc;
        }

        bool nextEvent(ref Event event) shared {
            import std.math : sqrt;
            synchronized {
                if (pollfds.length == 0)
                    return false;

                foreach(ref fds; pollfds[0 .. countFd]) {
                    fds.revents = 0;
                }

                int count = poll(cast(pollfd*)pollfds.ptr, countFd, 0);

                if (count <= 0) {
                    auto err = errno();
                    if (err == EINTR) {
                        // ok, timeout
                    }
                } else {
                    foreach(i, fds; pollfds[0 .. countFd]) {
                        // call handles callbacks
                        if (fds.revents == 0) continue;

                        auto callback = callbacks[i];
                        if (callback !is null)
                            callback(fds.events);
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
}

