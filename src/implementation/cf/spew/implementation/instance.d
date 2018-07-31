/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.instance;
import cf.spew.instance;
import cf.spew.ui.features;
import cf.spew.ui.window.defs;
import stdx.allocator : IAllocator, ISharedAllocator, make, dispose, processAllocator, theAllocator, makeArray;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import devisualization.util.core.memory.managed;
import x11b = devisualization.bindings.x11;
import cf.spew.ui.rendering : vec2;
import std.socket :  InternetAddress, Internet6Address;
import core.time : Duration, seconds, nsecs;
import core.thread : ThreadID, Thread;

// \/ clipboard data

shared(ISharedAllocator) clipboardDataAllocator;

// /\ clipboard data
// \/ TLS clipboard data

x11b.Window clipboardReceiveWindowHandleX11, clipboardSendWindowHandleX11;
char[] clipboardSendData;

static ~this() {
    if (clipboardDataAllocator !is null && clipboardSendData.length > 0) {
        clipboardDataAllocator.dispose(clipboardSendData);
    }
}

// /\ TLS clipboard data

final class DefaultImplementation : Instance {
    import cf.spew.event_loop.defs : EventLoopSource, EventLoopConsumer;
    import cf.spew.implementation.consumers;
    import core.thread : ThreadID, Thread;

    ~this() {
        if (__Initialized) {
            if (_eventLoop !is null) allocator.dispose(_eventLoop);
            if (_userInterface !is null) allocator.dispose(_userInterface);
            if (_streamInstance !is null) allocator.dispose(_streamInstance);

            if (_secondaryEventSource_ !is null) allocator.dispose(_secondaryEventSource_);
            if (_mainEventSource_ !is null) allocator.dispose(_mainEventSource_);
            if (_mainEventConsumer_ !is null) allocator.dispose(_mainEventConsumer_);
        }
    }

    bool __Initialized;
    shared(ISharedAllocator) allocator;
    shared(Management_EventLoop) _eventLoop;
    shared(UIInstance) _userInterface;
    shared(StreamsInstance) _streamInstance;
    shared(Miscellaneous_Instance) _miscInstance;

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
    }

    // this can be safely inlined!
    pragma(inline, true)
    void __guardCheck() shared {
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
        version(all) {
            import cf.spew.event_loop.wells.libuv;

            _streamInstance = allocator.make!(shared(StreamsInstance_LibUV))(allocator);
            _eventLoop.manager.addSources(LibUVEventLoopSource.instance);
        }

        // linux EPoll support
        version(linux) {
            import cf.spew.event_loop.wells.epoll;
            _eventLoop.manager.addSources(EpollEventLoopSource.instance);
        }

        version(Windows) {
            import cf.spew.event_loop.wells.winapi;
            import cf.spew.implementation.windowing.misc : dxva2, shell32, user32,
                Shell_NotifyIconGetRect, CalculatePopupWindowPosition,
                GetMonitorCapabilities, GetMonitorBrightness, GetPhysicalMonitorsFromHMONITOR;
            import core.sys.windows.ole2 : OleInitialize;

            OleInitialize(null);
            dxva2.load(["dxva2.dll"]);
            shell32.load(["Shell32.dll"]);
            user32.load(["User32.dll"]);

            if (dxva2.isLoaded) {
                GetMonitorCapabilities = cast(typeof(GetMonitorCapabilities))dxva2.loadSymbol("GetMonitorCapabilities", false);
                GetMonitorBrightness = cast(typeof(GetMonitorBrightness))dxva2.loadSymbol("GetMonitorCapabilities", false);
                GetPhysicalMonitorsFromHMONITOR = cast(typeof(GetPhysicalMonitorsFromHMONITOR))dxva2.loadSymbol("GetMonitorCapabilities", false);
            }

            if (shell32.isLoaded) {
                Shell_NotifyIconGetRect = cast(typeof(Shell_NotifyIconGetRect))shell32.loadSymbol("Shell_NotifyIconGetRect", false);
            } else assert(0);

            if (user32.isLoaded) {
                CalculatePopupWindowPosition = cast(typeof(CalculatePopupWindowPosition))user32.loadSymbol("CalculatePopupWindowPosition", false);
            } else assert(0);

            _userInterface = allocator.make!(shared(UIInstance_WinAPI))(allocator);

            _mainEventSource_ = allocator.make!(shared(WinAPI_EventLoop_Source));
            _eventLoop.manager.addSources(_mainEventSource_);
            _mainEventConsumer_ = allocator.make!(shared(EventLoopConsumerImpl_WinAPI))(this);
            _eventLoop.manager.addConsumers(_mainEventConsumer_);
        }

        if (_userInterface is null) {
            if (__checkForX11()) {
                import devisualization.bindings.x11;
                import devisualization.bindings.libnotify.loader;
                import cf.spew.event_loop.wells.x11;
                import cf.spew.event_loop.wells.glib;

                x11.XkbSetDetectableAutoRepeat(x11Display(), true, null);

                Window tray = x11.XGetSelectionOwner(x11Display(), x11Atoms()._NET_SYSTEM_TRAY_S);
                if (tray != None)
                    _userInterface = allocator.make!(shared(UIInstance_X11_FreeDesktopNotify))(allocator);
                else
                    _userInterface = allocator.make!(shared(UIInstance_X11))(allocator);

                // The x11 well doesn't need to know about our abstraction
                // but it does need to get the XIC for it...
                _mainEventSource_ = allocator.make!(shared(X11EventLoopSource))(cast(X11GetXICDel)(delegate (whandle) {
                            import cf.spew.implementation.windowing.window : WindowImpl_X11;

                            auto w = _userInterface.windowToIdMapper[whandle];
                            if (w is null) return null;
                            else if (WindowImpl_X11 w2 = cast(WindowImpl_X11)w) {
                                if (w2.isClosed)
                                    return null;
                                else
                                    return w2.xic;
                            } else return null;
                        }));
                _eventLoop.manager.addSources(_mainEventSource_);

                _mainEventConsumer_ = allocator.make!(shared(EventLoopConsumerImpl_X11))(this);
                _eventLoop.manager.addConsumers(_mainEventConsumer_);
            }
        }
    }

    bool __checkForX11() shared {
        import devisualization.bindings.x11;
        import cf.spew.event_loop.wells.x11;
        return x11Display() !is null &&
            x11.XScreenNumberOfScreen !is null &&
                x11.XkbSetDetectableAutoRepeat !is null;
    }
}

final class EventLoopWrapper : Management_EventLoop {
    import cf.spew.event_loop.defs : IEventLoopManager;
    import cf.spew.implementation.manager;

    this(shared(ISharedAllocator) allocator) shared {
        this.allocator = allocator;
        _manager = allocator.make!(shared(EventLoopManager_Impl));
    }

    ~this()  {
        allocator.dispose(_manager);
    }

    shared(ISharedAllocator) allocator;
    shared(IEventLoopManager) _manager;

    bool isRunningOnMainThread() shared  { return _manager.runningOnMainThread; }
    bool isRunning() shared  { return _manager.runningOnMainThread || _manager.runningOnAuxillaryThreads; }
    void stopCurrentThread() shared  { _manager.runningOnThreadFor; }
    void stopAllThreads() shared  { _manager.stopAllThreads; }
    void execute() shared  { _manager.execute; }

    @property shared(IEventLoopManager) manager() shared { return _manager; }
}

abstract class UIInstance : Management_UserInterface, Have_NotificationMessage, Have_Management_Clipboard, Have_NotificationTray {
    import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
    import stdx.allocator : IAllocator, processAllocator;
    import devisualization.util.core.memory.managed;
    import std.experimental.containers.map;

    this(shared(ISharedAllocator) allocator) shared {
        this.allocator = allocator;
        windowToIdMapper = SharedMap!(size_t, IWindow)(allocator);
    }

    shared(ISharedAllocator) allocator;
    /// ONLY use this if IWindow has events enabled!
    shared(SharedMap!(size_t, IWindow)) windowToIdMapper;

    // notifications

    shared(ISharedAllocator) taskbarCustomIconAllocator;
    shared(ImageStorage!RGBA8) taskbarCustomIcon;
    managed!IWindow taskbarTrayWindow;
    ThreadID taskbarTrayWindowThread;

    //

    managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared { assert(0); }

    managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared
    { return cast(managed!IRenderPointCreator)createWindow(alloc); }

    managed!IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared
    { return cast(managed!IRenderPoint)createAWindow(alloc); }

    managed!IWindow createAWindow(IAllocator alloc = theAllocator()) shared {
        import cf.spew.ui.context.features.vram;

        auto creator = createWindow(alloc);
        creator.size = vec2!ushort(cast(short)800, cast(short)600);
        creator.assignVRamContext;
        return creator.createWindow();
    }

    @property {
        managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared { assert(0); }

        managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared { assert(0); }

        managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared { assert(0); }
    }

    // notifications

    shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared { return null; }

    shared(Feature_NotificationTray) __getFeatureNotificationTray() shared { return null; }

    // clipboard

    shared(Feature_Management_Clipboard) __getFeatureClipboard() shared { return null; }
}

version(Windows) {
    final class UIInstance_WinAPI : UIInstance, Feature_NotificationMessage, Feature_Management_Clipboard, Feature_NotificationTray {
        import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_WinAPI;
        import cf.spew.implementation.windowing.window : WindowImpl_WinAPI;
        import cf.spew.implementation.windowing.misc : GetPrimaryDisplay_WinAPI, GetDisplays_WinAPI, GetWindows_WinAPI,
            NOTIFYICON_VERSION_4, imageToIcon_WinAPI, NIF_SHOWTIP, NIF_REALTIME;
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObjectFrom;
        import std.typecons : tuple;
        import winapi = core.sys.windows.windows;
        import winapishell = core.sys.windows.shellapi;
        import core.sys.windows.w32api : _WIN32_IE;

        version(none) {
            winapi.HWND taskbarIconWindow;
        }

        winapi.NOTIFYICONDATAW taskbarIconNID;

        size_t maxClipboardSizeV = size_t.max;

        static shared(UIInstance_WinAPI) MyInstance;

        this(shared(ISharedAllocator) allocator) shared {
            super(allocator);
            UIInstance_WinAPI.MyInstance = this;
        }

        static ~this() {
            if (!(cast()UIInstance_WinAPI.MyInstance.taskbarTrayWindow).isNull &&
                Thread.getThis().id == cast()UIInstance_WinAPI.MyInstance.taskbarTrayWindowThread) {

                UIInstance_WinAPI.MyInstance.setNotificationWindow(managed!IWindow.init);
                cast()UIInstance_WinAPI.MyInstance.taskbarTrayWindow = managed!IWindow.init;
            }
        }

        override {
            managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
                return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(), tuple(this, alloc), alloc);
            }

            @property {
                managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
                    GetPrimaryDisplay_WinAPI ctx = GetPrimaryDisplay_WinAPI(alloc, this);
                    ctx.call;

                    if (ctx.display is null)
                        return managed!IDisplay.init;
                    else
                        return managed!IDisplay(ctx.display, managers(ReferenceCountedManager()), alloc);
                }

                managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
                    GetDisplays_WinAPI ctx = GetDisplays_WinAPI(alloc, this);
                    ctx.call;
                    return managed!(IDisplay[])(ctx.displays, managers(ReferenceCountedManager()), alloc);
                }

                managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
                    GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc, this);
                    ctx.call;
                    return managed!(IWindow[])(ctx.windows, managers(ReferenceCountedManager()), alloc);
                }
            }

            // clipboard

            shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
                return winapi.OpenClipboard(null) != 0 ? this : null;
            }

            @property {
                void maxClipboardDataSize(size_t amount) shared { maxClipboardSizeV = amount; }

                size_t maxClipboardDataSize() shared { return maxClipboardSizeV; }

                managed!string clipboardText(IAllocator alloc, Duration timeout=0.seconds) shared {
                    import std.utf : byChar, codeLength;
                    char[] ret;

                    winapi.HANDLE h = winapi.GetClipboardData(winapi.CF_UNICODETEXT);
                    if (h !is null) {
                        wchar* theData = cast(wchar*)winapi.GlobalLock(h);
                        size_t theDataLength, realDataLength;
                        while(theData[theDataLength++] != 0) {}
                        wchar[] theData2 = theData[0 .. theDataLength-1];

                        realDataLength = theData2.codeLength!char;
                        ret = alloc.makeArray!char(realDataLength);
                        size_t offset;
                        foreach(c; theData2.byChar)
                            ret[offset++] = c;

                        winapi.GlobalUnlock(h);
                    } else {
                        h = winapi.GetClipboardData(winapi.CF_TEXT);

                        if (h !is null) {
                            char* theData = cast(char*)winapi.GlobalLock(h);
                            size_t theDataLength;
                            while(theData[theDataLength++] != 0) {}

                            ret = alloc.makeArray!char(theDataLength-1);
                            ret[] = theData[0 .. theDataLength];

                            winapi.GlobalUnlock(h);
                        }
                    }

                    winapi.CloseClipboard();

                    if (ret !is null)
                        return managed!string(cast(string)ret, managers(), alloc);
                    else
                        return managed!string.init;
                }

                void clipboardText(scope string text) shared {
                    import std.utf : byWchar, codeLength;
                    winapi.EmptyClipboard();

                    size_t realLength = text.codeLength!char;
                    winapi.HGLOBAL hglb = winapi.GlobalAlloc(winapi.GMEM_MOVEABLE, (realLength+1)*wchar.sizeof);

                    if (hglb !is null) {
                        wchar* wtext = cast(wchar*)winapi.GlobalLock(hglb);
                        size_t offset;

                        foreach(c; text.byWchar)
                            wtext[offset++] = c;

                        winapi.GlobalUnlock(hglb);
                        winapi.SetClipboardData(winapi.CF_UNICODETEXT, hglb);
                    }

                    winapi.CloseClipboard();
                }
            }

            // notifications

            shared(Feature_NotificationTray) __getFeatureNotificationTray() shared { return this; }

            @property {
                managed!IWindow getNotificationWindow(IAllocator alloc) shared {
                    if (cast()taskbarTrayWindow is managed!IWindow.init || taskbarTrayWindowThread != Thread.getThis().id)
                        return managed!IWindow.init;
                    else
                        return cast()taskbarTrayWindow;
                }

                void setNotificationWindow(managed!IWindow window) shared {
                    import cf.spew.event_loop.wells.winapi : AllocatedWM_USER;
                    bool modify;

                    if (!(cast()taskbarTrayWindow).isNull) {
                        winapi.HWND primaryHandle = cast(winapi.HWND)(cast()taskbarTrayWindow).__handle;
                        if (!window.isNull && primaryHandle is cast(winapi.HWND)(cast()window).__handle)
                            modify = true;
                        else {
                            winapi.Shell_NotifyIcon(winapi.NIM_DELETE, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
                            cast()taskbarTrayWindow = managed!IWindow.init;
                            taskbarIconNID = typeof(taskbarIconNID).init;
                        }
                    }

                    if (!window.isNull) {
                        cast()taskbarTrayWindow = window;
                        taskbarTrayWindowThread = Thread.getThis().id;

                        taskbarIconNID = winapi.NOTIFYICONDATAW.init;
                        taskbarIconNID.cbSize = winapi.NOTIFYICONDATAW.sizeof;
                        taskbarIconNID.uVersion = NOTIFYICON_VERSION_4;
                        taskbarIconNID.uFlags = winapi.NIF_ICON | winapi.NIF_MESSAGE;
                        taskbarIconNID.hIcon = cast(shared)(cast(managed!WindowImpl_WinAPI)cast()taskbarTrayWindow).hIcon;
                        taskbarIconNID.hWnd = cast(shared(winapi.HWND))(cast()taskbarTrayWindow).__handle;
                        taskbarIconNID.uCallbackMessage = AllocatedWM_USER.NotificationTray;

                        if (taskbarIconNID.hIcon is null)
                            taskbarIconNID.hIcon = cast(shared(winapi.HICON))winapi.SendMessage(cast(winapi.HWND)taskbarIconNID.hWnd, winapi.WM_GETICON, cast(winapi.WPARAM)winapi.ICON_SMALL, 80);
                        if (taskbarIconNID.hIcon is null)
                            taskbarIconNID.hIcon = cast(shared(winapi.HICON))winapi.GetClassLongPtr(cast(winapi.HWND)taskbarIconNID.hWnd, winapi.GCL_HICON);

                        if (modify)
                            winapi.Shell_NotifyIconW(winapi.NIM_MODIFY, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
                        else
                            winapi.Shell_NotifyIconW(winapi.NIM_ADD, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
                        winapi.Shell_NotifyIconW(winapi.NIM_SETVERSION, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
                    }
                }
            }

            bool haveNotificationWindow() shared {
                return cast()taskbarTrayWindow is managed!IWindow.init;
            }

            shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared { return this; }

            void notify(shared(ImageStorage!RGBA8) icon, dstring title, dstring text, shared(ISharedAllocator) alloc) shared {
                import std.utf : byUTF;
                if ((cast()taskbarTrayWindow).isNull)
                    return;

                winapi.NOTIFYICONDATAW nid = cast(winapi.NOTIFYICONDATAW)taskbarIconNID;
                nid.cbSize = winapi.NOTIFYICONDATAW.sizeof;
                nid.uVersion = NOTIFYICON_VERSION_4;
                nid.uFlags = winapi.NIF_ICON | NIF_SHOWTIP | winapi.NIF_INFO | NIF_REALTIME;
                nid.hWnd = cast(winapi.HWND)(cast()taskbarTrayWindow).__handle;

                size_t i;
                foreach(c; byUTF!wchar(title)) {
                    if (i >= nid.szInfoTitle.length - 1) {
                        nid.szInfoTitle[i] = cast(wchar)0;
                        break;
                    } else
                        nid.szInfoTitle[i] = c;

                    i++;
                    if (i == title.length)
                        nid.szInfoTitle[i] = cast(wchar)0;
                }

                i = 0;
                foreach(c; byUTF!wchar(text)) {
                    if (i >= nid.szInfo.length - 1) {
                        nid.szInfo[i] = cast(wchar)0;
                        break;
                    } else
                        nid.szInfo[i] = c;

                    i++;
                    if (i == text.length)
                        nid.szInfo[i] = cast(wchar)0;
                }

                winapi.HDC hFrom = winapi.GetDC(null);
                winapi.HDC hMemoryDC = winapi.CreateCompatibleDC(hFrom);

                scope(exit) {
                    winapi.DeleteDC(hMemoryDC);
                    winapi.ReleaseDC(null, hFrom);
                }

                if (icon !is null)
                    nid.hIcon = imageToIcon_WinAPI(icon, hMemoryDC, alloc);

                winapi.Shell_NotifyIconW(winapi.NIM_MODIFY, &nid);
                winapi.Shell_NotifyIconW(winapi.NIM_MODIFY, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
                winapi.DeleteObject(nid.hIcon);
            }

            void clearNotifications() shared {}
        }
    }
}

class UIInstance_X11 : UIInstance, Feature_Management_Clipboard {
    import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_X11;
    import cf.spew.implementation.windowing.display : DisplayImpl_X11;
    import cf.spew.implementation.windowing.misc : GetWindows_X11, X11WindowProperty, x11ReadWindowProperty;
    import cf.spew.event_loop.wells.x11;
    import devisualization.bindings.x11;
    import devisualization.image.storage.base : ImageStorageHorizontal;
    import devisualization.image.interfaces : imageObjectFrom;
    import std.typecons : tuple;
    import core.thread : Thread;

    size_t maxClipboardSizeV = size_t.max;

    this(shared(ISharedAllocator) allocator) shared {
        super(allocator);
        clipboardDataAllocator = allocator;
    }

    override {
        managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
            return cast(managed!IWindowCreator)managed!WindowCreatorImpl_X11(managers(), tuple(this, alloc), alloc);
        }

        @property {
            managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
                auto screenNumber = x11.XDefaultScreen(x11Display());
                Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
                Window rootWindow = x11.XRootWindowOfScreen(theScreen);

                IDisplay theDisplay;
                int numMonitors;
                XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), rootWindow, true, &numMonitors);

                scope(exit)
                    x11.XRRFreeMonitors(monitors);

                foreach(i; 0 .. numMonitors) {
                    if (monitors[i].primary) {
                        theDisplay = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc, this);
                        break;
                    }
                }

                if (theDisplay is null && numMonitors == 0)
                    return managed!IDisplay.init;
                else if (theDisplay is null) // why did we not get it? Who knows.
                    theDisplay = alloc.make!DisplayImpl_X11(theScreen, &monitors[0], alloc, this);

                return managed!IDisplay(theDisplay, managers(ReferenceCountedManager()), alloc);
            }

            managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
                auto screenNumber = x11.XDefaultScreen(x11Display());
                Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
                Window rootWindow = x11.XRootWindowOfScreen(theScreen);

                int numMonitors;
                XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), rootWindow, true, &numMonitors);

                if (numMonitors == -1)
                    return managed!(IDisplay[]).init;

                IDisplay[] ret = alloc.makeArray!IDisplay(cast(size_t)numMonitors);
                foreach(i; 0 .. numMonitors) {
                    ret[i] = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc, this);
                }

                x11.XRRFreeMonitors(monitors);
                return managed!(IDisplay[])(ret, managers(ReferenceCountedManager()), alloc);
            }

            managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
                GetWindows_X11 ctx;
                ctx.alloc = alloc;
                ctx.uiInstance = this;
                ctx.call;

                return managed!(IWindow[])(ctx.windows, managers(ReferenceCountedManager()), alloc);
            }
        }

        // clipboard

        shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
            return this;
        }

        @property {
            void maxClipboardDataSize(size_t amount) shared { maxClipboardSizeV = amount; }

            size_t maxClipboardDataSize() shared { return maxClipboardSizeV; }

            managed!string clipboardText(IAllocator alloc, Duration timeout=0.seconds) shared {
                import std.datetime.stopwatch;
                guardClipboard();

                auto CLIPBOARD = x11Atoms().CLIPBOARD;
                if (clipboardReceiveWindowHandleX11 == None || CLIPBOARD == None ||
                    x11.XGetSelectionOwner(x11Display(), x11Atoms().CLIPBOARD) == None) {
                    return managed!string.init;
                }

                Window owner = x11.XGetSelectionOwner(x11Display(), CLIPBOARD);

                // thread owns clipboard, woops
                // so we special case so nothing blocks up
                if (owner == clipboardSendWindowHandleX11) {
                    char[] ret = alloc.makeArray!char(clipboardSendData.length);
                    ret[] = cast(char[])clipboardSendData[];
                    return managed!string(cast(string)ret, managers(), alloc);
                }

                XEvent event;

                // remove any existing events that exist
                while(x11.XCheckWindowEvent(x11Display(), clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True) {}

                x11.XConvertSelection(x11Display(), CLIPBOARD, x11Atoms().UTF8_STRING, CLIPBOARD, clipboardReceiveWindowHandleX11, CurrentTime);
                if (timeout.total!"hnsecs" == 0) {
                    for(;;) {
                        if (x11.XCheckTypedWindowEvent(x11Display(), clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True)
                            return clipboardGetContents(alloc, CLIPBOARD);

                        Thread.getThis().sleep(1.nsecs);
                    }
                } else {
                    StopWatch sw;
                    sw.start();

                    while(sw.peek < timeout) {
                        if (x11.XCheckTypedWindowEvent(x11Display(), clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True)
                            return clipboardGetContents(alloc, CLIPBOARD);

                        Thread.getThis().sleep(1.nsecs);
                    }

                    sw.stop();
                }

                return managed!string.init;
            }

            void clipboardText(scope string text) shared {
                guardClipboard();

                if (text.length > maxClipboardSizeV)
                    text = text[0 .. maxClipboardSizeV];


                if (clipboardSendData.length > 0)
                    clipboardDataAllocator.dispose(clipboardSendData);
                clipboardSendData = clipboardDataAllocator.makeArray!char(text.length);
                clipboardSendData[] = text[];

                x11.XSetSelectionOwner(x11Display(), x11Atoms().CLIPBOARD, clipboardSendWindowHandleX11, CurrentTime);
            }
        }
    }

    private {
        void guardClipboard() shared {
            if (clipboardReceiveWindowHandleX11 == None) {
                clipboardReceiveWindowHandleX11 = x11.XCreateSimpleWindow(x11Display(), x11.XRootWindow(x11Display(), x11.XDefaultScreen(x11Display())), int.min, int.min, 1, 1, 0, 0, 0);
                x11.XSelectInput(x11Display(), clipboardReceiveWindowHandleX11, SelectionNotify);

                clipboardSendWindowHandleX11 = x11.XCreateSimpleWindow(x11Display(), x11.XRootWindow(x11Display(), x11.XDefaultScreen(x11Display())), int.min, int.min, 1, 1, 0, 0, 0);
                x11.XSelectInput(x11Display(), clipboardSendWindowHandleX11, SelectionClear | SelectionRequest);
            }
        }

        managed!string clipboardGetContents(IAllocator alloc, Atom property) shared {
            X11WindowProperty value = x11ReadWindowProperty(x11Display(), clipboardReceiveWindowHandleX11, property);

            if (value.data !is null && value.numberOfItems > 0) {
                char[] ret;

                // well we did ask for it to be limited...
                if (value.numberOfItems <= maxClipboardSizeV) {
                    ret = alloc.makeArray!char(value.numberOfItems);
                    ret[] = cast(char[])value.data[0 .. value.numberOfItems][];

                    x11.XFree(value.data);
                    x11.XDeleteProperty(x11Display(), clipboardReceiveWindowHandleX11, property);
                    return managed!string(cast(string)ret, managers(), alloc);
                } else {
                    x11.XFree(value.data);
                    x11.XDeleteProperty(x11Display(), clipboardReceiveWindowHandleX11, property);
                    return managed!string.init;
                }
            } else {
                return managed!string.init;
            }
        }
    }
}

// https://standards.freedesktop.org/systemtray-spec/systemtray-spec-0.3.html#idm139990069470464
// https://standards.freedesktop.org/xembed-spec/xembed-spec-latest.html
// http://distro.ibiblio.org/vectorlinux/Uelsk8s/GAMBAS/gambas-svn/gambas2/gb.gtk/src/gtrayicon.cpp
class UIInstance_X11_FreeDesktopNotify : UIInstance_X11, Feature_NotificationMessage, Feature_NotificationTray {
    import cf.spew.event_loop.wells.x11;
    import devisualization.bindings.x11;
    import cf.spew.implementation.windowing.misc : x11WindowAttributes,
                x11SendFreeDesktopSystemTrayMessage, FreeDesktopSystemTray;

    Window taskbarSysTrayOwner, taskbarSysTrayWrapper;
    Window[8] wrappersToClean;
    ThreadID[8] wrappersToCleanThreads;
    Visual* theVisual;
    GC taskbarSysTrayGC;
    uint bubbleIdNum;

    this(shared(ISharedAllocator) allocator) shared {
        super(allocator);
    }

    override shared(Feature_NotificationTray) __getFeatureNotificationTray() shared { return this; }

    @property {
        managed!IWindow getNotificationWindow(IAllocator alloc) shared {
            if (cast()taskbarTrayWindow is managed!IWindow.init || taskbarTrayWindowThread != Thread.getThis().id)
                return managed!IWindow.init;
            else
                return cast()taskbarTrayWindow;
        }

        void setNotificationWindow(managed!IWindow window) shared {
            cast()taskbarTrayWindow = window;
            __guardSysTray();
        }

        bool haveNotificationWindow() shared {
            return cast()taskbarTrayWindow !is managed!IWindow.init;
        }
    }

    override shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared { return this; }

    void notify(shared(ImageStorage!RGBA8) icon, dstring title, dstring text, shared(ISharedAllocator) alloc) shared {
        import std.utf : byChar, codeLength;
        import std.range : drop;

        size_t titleL = title.codeLength!char;
        size_t textL = text.codeLength!char;
        size_t offset;
        bool sentNewLine;

        size_t fullLen = titleL + textL;
        if (title.length > 0 && title[$-1] != '\n') {
            fullLen++;
            sentNewLine = true;
        }

        // SYSTEM_TRAY_BEGIN_MESSAGE
        //    l[2] contains the timeout in thousandths of a second or zero for infinite timeout
        //    l[3] contains the length of the message string in bytes, not including any nul bytes
        //    l[4] contains an ID number for the message. This ID number should never be reused by the same tray icon.
        x11SendFreeDesktopSystemTrayMessage(x11Display(), taskbarSysTrayOwner,
            FreeDesktopSystemTray.SYSTEM_TRAY_BEGIN_MESSAGE, 0, cast(uint)fullLen, bubbleIdNum);
        bubbleIdNum = bubbleIdNum + 1;

        // _NET_SYSTEM_TRAY_MESSAGE_DATA
        //    must have their window field set to the window ID of the tray icon, and have a format of 8

        offset = 0;
        while(offset < titleL) {
            XEvent ev;
            ev.xclient.type = ClientMessage;
            ev.xclient.window = taskbarSysTrayOwner;
            ev.xclient.message_type = x11Atoms()._NET_SYSTEM_TRAY_MESSAGE_DATA;
            ev.xclient.format = 8;

            size_t offset2;
            foreach(c; title.byChar.drop(offset)) {
                ev.xclient.data.b[offset2++] = c;
                if (offset2 == 20) break;
                offset++;
            }

            if (offset2 < 20 && offset == titleL) {
                ev.xclient.data.b[offset2++] = '\n';
                sentNewLine = true;
            }

            x11.XSendEvent(x11Display(), taskbarSysTrayOwner, False, NoEventMask, &ev);
        }

        offset = 0;
        while(offset < textL) {
            XEvent ev;
            ev.xclient.type = ClientMessage;
            ev.xclient.window = taskbarSysTrayOwner;
            ev.xclient.message_type = x11Atoms()._NET_SYSTEM_TRAY_MESSAGE_DATA;
            ev.xclient.format = 8;

            size_t offset2;

            if (offset == 0 && !sentNewLine) {
                ev.xclient.data.b[offset2++] = '\n';
            }

            foreach(c; text.byChar.drop(offset)) {
                ev.xclient.data.b[offset2++] = c;
                if (offset2 == 20) break;
                offset++;
            }

            x11.XSendEvent(x11Display(), taskbarSysTrayOwner, False, NoEventMask, &ev);
        }
    }

    void clearNotifications() shared {}

    package(cf.spew.implementation) {
        void __guardSysTray() shared {
            ThreadID myThreadID = Thread.getThis().id;
            Window trayOwner = x11.XGetSelectionOwner(x11Display(), x11Atoms()._NET_SYSTEM_TRAY_S);

            foreach(i, ref whandle; wrappersToClean) {
                if (whandle == None) continue;
                else if (wrappersToCleanThreads[i] == myThreadID) {
                    x11.XUnmapWindow(x11Display(), whandle);
                    x11.XDestroyWindow(x11Display(), whandle);
                    whandle = None;
                }
            }

            if (taskbarSysTrayWrapper != None && (taskbarTrayWindowThread != myThreadID ||
                trayOwner != taskbarSysTrayOwner || !haveNotificationWindow())) {

                foreach(i, whandle; wrappersToClean) {
                    if (whandle == None) {
                        whandle = taskbarSysTrayWrapper;
                        wrappersToCleanThreads[i] = taskbarTrayWindowThread;
                        taskbarSysTrayWrapper = None;

                        x11.XFree(cast(Visual*)theVisual);
                        x11.XFreeGC(x11Display(), cast(GC)taskbarSysTrayGC);
                        theVisual = null;
                        taskbarSysTrayGC = null;
                        goto assign;
                    }
                }

                assert(0, "Too many old wrapper handles!");
            }
        assign:

            if (haveNotificationWindow() && (taskbarSysTrayWrapper == None ||
                (taskbarSysTrayOwner == None && taskbarTrayWindowThread == myThreadID))) {

                taskbarTrayWindowThread = Thread.getThis().id;
                taskbarSysTrayOwner = trayOwner;

                Window wroot = x11.XRootWindow(x11Display(), x11.XDefaultScreen(x11Display()));
                auto rootattr = x11WindowAttributes(wroot);
                auto size = rootattr.width > rootattr.height ? rootattr.height : rootattr.width;

                // create wrapper window

                auto systrayVisual = x11ReadWindowProperty(x11Display(), taskbarSysTrayOwner, x11Atoms()._NET_SYSTEM_TRAY_VISUAL);
                XVisualInfo* visualInfo;

                if (systrayVisual.format == 32 && systrayVisual.numberOfItems == 1) {
                    XVisualInfo visualTemplate;
                    visualTemplate.visualid = *cast(VisualID*)systrayVisual.data;
                    int allVisualsCount;

                    visualInfo = x11.XGetVisualInfo(x11Display(), VisualIDMask, &visualTemplate, &allVisualsCount);
                }

                if (visualInfo is null) {
                    theVisual = cast(shared)x11.XDefaultVisual(x11Display(), x11.XDefaultScreen(x11Display()));
                    assert(theVisual !is null);

                    XVisualInfo visualTemplate;
                    visualTemplate.visualid = x11.XVisualIDFromVisual(cast(Visual*)theVisual);
                    int allVisualsCount;

                    visualInfo = x11.XGetVisualInfo(x11Display(), VisualIDMask, &visualTemplate, &allVisualsCount);

                    assert(allVisualsCount >= 1);
                    assert(visualTemplate.visualid == visualInfo.visualid);
                }

                if (visualInfo !is null) {
                    XSetWindowAttributes swa;
                    Colormap cmap;

                    cmap = x11.XCreateColormap(x11Display(), wroot, visualInfo.visual, AllocNone);
                    swa.colormap = cmap;
                    swa.background_pixmap = None;
                    swa.border_pixel = 0;
                    swa.background_pixel = 0xDEFACE00;

                    taskbarSysTrayWrapper = x11.XCreateWindow(x11Display(), wroot,
                        0, 0, size, size, 0, visualInfo.depth, InputOutput,
                        visualInfo.visual, CWBorderPixel|CWColormap|CWBackPixel, &swa);
                    bubbleIdNum = 0;

                    assert(taskbarSysTrayWrapper != None);
                    x11.XFree(visualInfo);
                }

                // backup plan
                if (taskbarSysTrayWrapper == None)
                    taskbarSysTrayWrapper = x11.XCreateSimpleWindow(x11Display(), wroot, 0, 0, size, size, 0, 0, 0xDEFACE00);

                // select
                x11.XSelectInput(x11Display(), taskbarSysTrayOwner, StructureNotifyMask);
                x11.XSelectInput(x11Display(), taskbarSysTrayWrapper, ExposureMask | ButtonPressMask | StructureNotifyMask);

                // dock
                x11SendFreeDesktopSystemTrayMessage(x11Display(), taskbarSysTrayOwner,
                    FreeDesktopSystemTray.SYSTEM_TRAY_REQUEST_DOCK, taskbarSysTrayWrapper, 0, 0);

                // map
                x11.XSync(x11Display(), False);

                // graphics context
                taskbarSysTrayGC = cast(shared)x11.XCreateGC(x11Display(), taskbarSysTrayWrapper, 0, null);
                assert(taskbarSysTrayGC !is null);
            }
        }

        void drawSystray(uint width, uint height, uint* data) shared {
            import cf.spew.implementation.windowing.misc : x11WindowAttributes, bilinearInterpolationScale;
            import core.stdc.stdlib : malloc, free;

            auto attr = x11WindowAttributes(taskbarSysTrayWrapper);

            if (attr.width != width || attr.height != height) {
                uint* temp = cast(uint*)malloc(4*attr.width*attr.height);

                bilinearInterpolationScale(width, height, attr.width, attr.height, cast(ubyte[4]*)data, cast(ubyte[4]*)temp);

                free(data);
                data = temp;

                width = attr.width;
                height = attr.height;
            }

            XImage* x11Image = x11.XCreateImage(x11Display(), cast(Visual*)taskbarSysTrayGC, 24, ZPixmap, 0, cast(char*)data, width, height, 32, 0);
            x11.XPutImage(x11Display(), cast(Window)taskbarSysTrayWrapper, cast(GC)taskbarSysTrayGC, x11Image, 0, 0, 0, 0, attr.width, attr.height);
            x11.XDestroyImage(x11Image);
        }
    }
}

abstract class StreamsInstance : Management_Streams {
    import cf.spew.streams;
    import std.socket : Address;
    import stdx.allocator : ISharedAllocator, processAllocator;

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

class StreamsInstance_LibUV : StreamsInstance {
    import cf.spew.streams;

    this(shared(ISharedAllocator) allocator) shared {
        super(allocator);
    }

    managed!ISocket_TCPServer tcpServer(Address address, ushort listBacklogAmount=64, IAllocator alloc=theAllocator()) shared {
        import cf.spew.implementation.streams.tcp_server : LibUVTCPServer;
        return LibUVTCPServer.create(address, listBacklogAmount, alloc);
    }
    managed!ISocket_TCP tcpConnect(Address address, IAllocator alloc=theAllocator()) shared {
        import cf.spew.implementation.streams.tcp : LibUVTCPSocket;
        return LibUVTCPSocket.create(address, alloc);
    }
    managed!ISocket_UDPLocalPoint udpLocalPoint(Address address, IAllocator alloc=theAllocator()) shared {
        import cf.spew.implementation.streams.udp : LibUVUDPLocalPoint;
        return LibUVUDPLocalPoint.create(address, alloc);
    }

    managed!(managed!Address[]) allLocalAddress(IAllocator alloc=theAllocator()) shared {
        import devisualization.bindings.libuv;
        if (alloc is null) return managed!(managed!Address[]).init;

        managed!Address[] ret;

        int count;
        uv_interface_address_t* addresses;
        libuv.uv_interface_addresses(&addresses, &count);

        ret = cast(managed!Address[])alloc.makeArray!(ubyte)(count * managed!Address.sizeof);
        foreach(i, v; addresses[0 .. count]) {
            if (v.address.address4.sin_family == AF_INET) {
                ret[i] = cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(v.address.address4), managers(), alloc);
            } else if (v.address.address4.sin_family == AF_INET6) {
                ret[i] = cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(v.address.address6), managers(), alloc);
            } else {
                ret[i] = managed!Address.init;
            }
        }

        libuv.uv_free_interface_addresses(addresses, count);
        return managed!(managed!Address[])(ret, managers(), alloc);
    }
}

class Miscellaneous_Instance : Management_Miscellaneous {
    import cf.spew.miscellaneous;
    import std.experimental.containers.map;
    import core.time : Duration;

    shared(SharedMap!(size_t, ITimer)) timerToIdMapper;

    this(shared(ISharedAllocator) alloc) shared {
        timerToIdMapper = SharedMap!(size_t, ITimer)(alloc);
    }

    managed!ITimer createTimer(Duration timeout, bool hintSystemWait=true, IAllocator alloc=theAllocator()) shared {
        import cf.spew.implementation.misc.timer;
        ITimer ret;

        if (hintSystemWait) {
            version(Windows) {
                ret = alloc.make!WinAPITimer(this, timeout);
            }
        }

        if (ret is null) {
            ret = alloc.make!LibUVTimer(timeout);
        }

        return managed!ITimer(ret, managers(), alloc);
    }

    managed!IFileSystemWatcher createFileSystemWatcher(string path, IAllocator alloc=theAllocator()) shared {
        import cf.spew.implementation.misc.filewatcher;
        IFileSystemWatcher ret;

        ret = alloc.make!LibUVFileSystemWatcher(path, alloc);

        return managed!IFileSystemWatcher(ret, managers(), alloc);
    }
}
