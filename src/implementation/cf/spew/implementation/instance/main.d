module cf.spew.implementation.instance.main;
import cf.spew.implementation.instance.misc;
import cf.spew.implementation.instance.streams.base;
import cf.spew.implementation.instance.ui.base;
import cf.spew.implementation.instance.eventloop;
import cf.spew.implementation.instance.state : windowToIdMapper;
import cf.spew.instance;
import cf.spew.event_loop.defs : EventLoopSource, EventLoopConsumer;
import stdx.allocator : ISharedAllocator, make, dispose, processAllocator;
import core.thread : ThreadID, Thread;

final class DefaultImplementation : Instance {
    static shared(DefaultImplementation) Instance = new shared DefaultImplementation;

    ~this() {
        if (__Initialized) {
            if (_eventLoop !is null)
                allocator.dispose(_eventLoop);
            if (_userInterface !is null)
                allocator.dispose(_userInterface);
            if (_streamInstance !is null)
                allocator.dispose(_streamInstance);
            if (_miscInstance !is null)
                allocator.dispose(_miscInstance);
            if (_robotInstance !is null)
                allocator.dispose(_robotInstance);

            if (_secondaryEventSource_ !is null)
                allocator.dispose(_secondaryEventSource_);
            if (_mainEventSource_ !is null)
                allocator.dispose(_mainEventSource_);
            if (_mainEventConsumer_ !is null)
                allocator.dispose(_mainEventConsumer_);
        }
    }

    bool __Initialized;
    shared(ISharedAllocator) allocator;
    shared(Management_EventLoop) _eventLoop;
    shared(Management_UserInterface) _userInterface;
    shared(StreamsInstance) _streamInstance;
    shared(Miscellaneous_Instance) _miscInstance;
    shared(Management_Robot) _robotInstance;

    @property {
        override shared(Management_EventLoop) eventLoop() shared {
            __guardCheck();
            return _eventLoop;
        }

        override shared(Management_UserInterface) userInterface() shared {
            __guardCheck();
            return _userInterface;
        }

        override shared(Management_Streams) streams() shared {
            __guardCheck();
            return _streamInstance;
        }

        override shared(Management_Miscellaneous) misc() shared {
            __guardCheck();
            return _miscInstance;
        }

        override shared(Management_Robot) robot() shared {
            __guardCheck();
            return _robotInstance;
        }
    }

    // this can be safely inlined!
    pragma(inline, true) void __guardCheck() shared {
        if (!__Initialized)
            __handleGuardCheck();
    }

    private {
        shared(EventLoopSource) _mainEventSource_, _secondaryEventSource_;
        shared(EventLoopConsumer) _mainEventConsumer_;
    }

    void __handleGuardCheck() shared {
        __Initialized = true;
        allocator = processAllocator();

        _eventLoop = allocator.make!(shared(EventLoopWrapper))(allocator);
        _miscInstance = allocator.make!(shared(Miscellaneous_Instance))(allocator);

        // LibUV stuff for streams support
        version (all) {
            import cf.spew.implementation.instance.streams.libuv;
            import cf.spew.event_loop.wells.libuv;

            _streamInstance = allocator.make!(shared(StreamsInstance_LibUV))(allocator);
            _eventLoop.manager.addSources(LibUVEventLoopSource.instance);
        }

        // linux EPoll support
        version (Posix) {
            import cf.spew.event_loop.wells.poll;

            _eventLoop.manager.addSources(PollEventLoopSource.instance);
        }

        version (Windows) {
            import cf.spew.implementation.windowing.utilities.winapi : dxva2,
                shell32, user32, Shell_NotifyIconGetRect,
                CalculatePopupWindowPosition, GetMonitorCapabilities,
                GetMonitorBrightness, GetPhysicalMonitorsFromHMONITOR;
            import cf.spew.implementation.consumers.winapi;
            import cf.spew.implementation.instance.robot.winapi;
            import cf.spew.implementation.instance.ui.winapi;
            import cf.spew.event_loop.wells.winapi;
            import core.sys.windows.ole2 : OleInitialize;

            OleInitialize(null);
            dxva2.load(["dxva2.dll"]);
            shell32.load(["Shell32.dll"]);
            user32.load(["User32.dll"]);

            if (dxva2.isLoaded) {
                GetMonitorCapabilities = cast(typeof(GetMonitorCapabilities))dxva2.loadSymbol(
                        "GetMonitorCapabilities", false);
                GetMonitorBrightness = cast(typeof(GetMonitorBrightness))dxva2.loadSymbol(
                        "GetMonitorCapabilities", false);
                GetPhysicalMonitorsFromHMONITOR = cast(typeof(GetPhysicalMonitorsFromHMONITOR))dxva2.loadSymbol(
                        "GetMonitorCapabilities", false);
            }

            if (shell32.isLoaded) {
                Shell_NotifyIconGetRect = cast(typeof(Shell_NotifyIconGetRect))shell32.loadSymbol(
                        "Shell_NotifyIconGetRect", false);
            } else
                assert(0);

            if (user32.isLoaded) {
                CalculatePopupWindowPosition = cast(typeof(CalculatePopupWindowPosition))user32.loadSymbol(
                        "CalculatePopupWindowPosition", false);
            } else
                assert(0);

            _userInterface = allocator.make!(shared(UIInstance_WinAPI))(allocator);
            _robotInstance = allocator.make!(shared(RobotInstance_WinAPI))();

            _mainEventSource_ = allocator.make!(shared(WinAPI_EventLoop_Source));
            _eventLoop.manager.addSources(_mainEventSource_);
            _mainEventConsumer_ = allocator.make!(shared(EventLoopConsumerImpl_WinAPI))();
            _eventLoop.manager.addConsumers(_mainEventConsumer_);
        }

        if (_userInterface is null) {
            version (Posix) {
                import cf.spew.implementation.instance.ui.x11 : UIInstance_X11,
                    checkForX11;
                import cf.spew.implementation.consumers.x11;
                import devisualization.bindings.x11;

                if (checkForX11()) {
                    import devisualization.bindings.x11;
                    import devisualization.bindings.libnotify.loader;
                    import cf.spew.event_loop.wells.x11;

                    x11.XkbSetDetectableAutoRepeat(x11Display(), true, null);
                    _userInterface = allocator.make!(shared(UIInstance_X11))(allocator);

                    // The x11 well doesn't need to know about our abstraction
                    // but it does need to get the XIC for it...
                    _mainEventSource_ = allocator.make!(shared(X11EventLoopSource))(
                            cast(X11GetXICDel)(delegate(whandle) {
                            import cf.spew.implementation.windowing.window.x11 : WindowImpl_X11;

                            auto w = windowToIdMapper[whandle];
                            if (w is null)
                                return null;
                            else if (WindowImpl_X11 w2 = cast(WindowImpl_X11)w) {
                                if (w2.isClosed)
                                    return null;
                                else
                                    return w2.xic;
                            } else
                                return null;
                        }));
                    _eventLoop.manager.addSources(_mainEventSource_);

                    _mainEventConsumer_ = allocator.make!(shared(EventLoopConsumerImpl_X11))();
                    _eventLoop.manager.addConsumers(_mainEventConsumer_);
                }
            }
        }
    }
}
