module cf.spew.implementation.instance.ui.x11;
version (Posix):
import cf.spew.implementation.instance.ui.base : UIInstance;
import cf.spew.implementation.instance.state : clipboardDataAllocator,
    clipboardReceiveWindowHandleX11, clipboardSendWindowHandleX11,
    clipboardSendData, taskbarTrayWindow, taskbarTrayWindowThread;
import cf.spew.implementation.windowing.window_creator.x11 : WindowCreatorImpl_X11;
import cf.spew.implementation.windowing.display.x11 : DisplayImpl_X11;
import cf.spew.implementation.windowing.utilities.x11 : GetWindows_X11,
    X11WindowProperty, x11ReadWindowProperty, x11WindowAttributes,
    x11SendFreeDesktopSystemTrayMessage, FreeDesktopSystemTray;
import cf.spew.implementation.windowing.utilities.misc : bilinearInterpolationScale;
import cf.spew.ui.features.notificationmessage;
import cf.spew.ui.features.notificationtray;
import cf.spew.ui.features.clipboard;
import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint,
    IRenderPointCreator;
import cf.spew.event_loop.wells.x11;
import devisualization.util.core.memory.managed;
import devisualization.bindings.x11;
import devisualization.image.storage.base : ImageStorageHorizontal;
import devisualization.image.interfaces : ImageStorage, imageObjectFrom;
import stdx.allocator : IAllocator, ISharedAllocator, make, dispose,
    processAllocator, theAllocator, makeArray;
import std.experimental.color : RGBA8;
import std.typecons : tuple;
import core.thread : Thread, ThreadID;
import core.time : Duration, seconds, nsecs;

final class UIInstance_X11 : UIInstance, Feature_Management_Clipboard {
    shared(Feature_NotificationTray) notificationTrayImpl;
    shared(Feature_NotificationMessage) notificationBubbleImpl;
    size_t maxClipboardSizeV = size_t.max;
    bool isTrayBubbleSame;

    this(shared(ISharedAllocator) allocator) shared {
        super(allocator);
        clipboardDataAllocator = allocator;

        Window freedesktopTray = x11.XGetSelectionOwner(x11Display(),
                x11Atoms()._NET_SYSTEM_TRAY_S);

        version(linux) {
            import cf.spew.implementation.instance.ui.notifications_sdbus;
            if (checkForSDBusKDETray()) {
                notificationTrayImpl = allocator.make!(shared(SDBus_KDENotifications))(allocator);
                if (checkForSDBusFreeDesktopBubble()) {
                    // sdbus KDE + sdbus KDE bubble
                    notificationBubbleImpl = cast(shared(Feature_NotificationMessage))notificationTrayImpl;
                    isTrayBubbleSame = true;
                } else {
                    // sdbus KDE + freedesktop bubble
                    notificationBubbleImpl = allocator.make!(shared(FreeDesktopNotifications))();
                }
            } else if (freedesktopTray != None) {
                notificationTrayImpl = allocator.make!(shared(FreeDesktopNotifications))();
                if (checkForSDBusFreeDesktopBubble()) {
                    // freedesktop + sdbus KDE bubble
                    notificationBubbleImpl = allocator.make!(shared(SDBus_KDENotifications))(allocator);
                } else {
                    // freedesktop + freedesktop bubble
                    notificationBubbleImpl = cast(shared(Feature_NotificationMessage))notificationTrayImpl;
                    isTrayBubbleSame = true;
                }
            } else {
                if (checkForSDBusFreeDesktopBubble()) {
                    // sdbus KDE bubble
                    notificationBubbleImpl = allocator.make!(shared(SDBus_KDENotifications))(allocator);
                }
            }
        } else {
            // freedesktop + freedesktop bubble
            notificationTrayImpl = allocator.make!(shared(FreeDesktopNotifications))();
            notificationBubbleImpl = cast(shared(Feature_NotificationMessage))notificationTrayImpl;
            isTrayBubbleSame = true;
        }
    }

    ~this() {
        if (notificationTrayImpl !is null) {
            allocator.dispose(notificationTrayImpl);
            if (!isTrayBubbleSame && notificationBubbleImpl !is null)
                allocator.dispose(notificationBubbleImpl);
        }
    }

    override {
        managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
            return cast(managed!IWindowCreator)managed!WindowCreatorImpl_X11(managers(),
                    tuple(alloc), alloc);
        }

        @property {
            managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
                auto screenNumber = x11.XDefaultScreen(x11Display());
                Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
                Window rootWindow = x11.XRootWindowOfScreen(theScreen);

                IDisplay theDisplay;
                int numMonitors;
                XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(),
                        rootWindow, true, &numMonitors);

                scope (exit)
                    x11.XRRFreeMonitors(monitors);

                foreach (i; 0 .. numMonitors) {
                    if (monitors[i].primary) {
                        theDisplay = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc);
                        break;
                    }
                }

                if (theDisplay is null && numMonitors == 0)
                    return managed!IDisplay.init;
                else if (theDisplay is null) // why did we not get it? Who knows.
                    theDisplay = alloc.make!DisplayImpl_X11(theScreen, &monitors[0], alloc);

                return managed!IDisplay(theDisplay, managers(ReferenceCountedManager()), alloc);
            }

            managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
                auto screenNumber = x11.XDefaultScreen(x11Display());
                Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
                Window rootWindow = x11.XRootWindowOfScreen(theScreen);

                int numMonitors;
                XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(),
                        rootWindow, true, &numMonitors);

                if (numMonitors == -1)
                    return managed!(IDisplay[]).init;

                IDisplay[] ret = alloc.makeArray!IDisplay(cast(size_t)numMonitors);
                foreach (i; 0 .. numMonitors) {
                    ret[i] = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc);
                }

                x11.XRRFreeMonitors(monitors);
                return managed!(IDisplay[])(ret, managers(ReferenceCountedManager()), alloc);
            }

            managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
                GetWindows_X11 ctx;
                ctx.alloc = alloc;
                ctx.call;

                return managed!(IWindow[])(ctx.windows, managers(ReferenceCountedManager()), alloc);
            }
        }

        // clipboard

        shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
            return this;
        }

        @property {
            void maxClipboardDataSize(size_t amount) shared {
                maxClipboardSizeV = amount;
            }

            size_t maxClipboardDataSize() shared {
                return maxClipboardSizeV;
            }

            managed!string clipboardText(IAllocator alloc, Duration timeout = 0.seconds) shared {
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
                while (x11.XCheckWindowEvent(x11Display(),
                        clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True) {
                }

                x11.XConvertSelection(x11Display(), CLIPBOARD, x11Atoms().UTF8_STRING,
                        CLIPBOARD, clipboardReceiveWindowHandleX11, CurrentTime);
                if (timeout.total!"hnsecs" == 0) {
                    for (;;) {
                        if (x11.XCheckTypedWindowEvent(x11Display(),
                                clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True)
                            return clipboardGetContents(alloc, CLIPBOARD);

                        Thread.getThis().sleep(1.nsecs);
                    }
                } else {
                    StopWatch sw;
                    sw.start();

                    while (sw.peek < timeout) {
                        if (x11.XCheckTypedWindowEvent(x11Display(),
                                clipboardReceiveWindowHandleX11, SelectionNotify, &event) == True)
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

                x11.XSetSelectionOwner(x11Display(), x11Atoms().CLIPBOARD,
                        clipboardSendWindowHandleX11, CurrentTime);
            }
        }
    }

    override shared(Feature_NotificationTray) __getFeatureNotificationTray() shared {
        return notificationTrayImpl;
    }

    override shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared {
        return notificationBubbleImpl;
    }

    private {
        void guardClipboard() shared {
            if (clipboardReceiveWindowHandleX11 == None) {
                clipboardReceiveWindowHandleX11 = x11.XCreateSimpleWindow(x11Display(),
                        x11.XRootWindow(x11Display(), x11.XDefaultScreen(x11Display())),
                        int.min, int.min, 1, 1, 0, 0, 0);
                x11.XSelectInput(x11Display(), clipboardReceiveWindowHandleX11, SelectionNotify);

                clipboardSendWindowHandleX11 = x11.XCreateSimpleWindow(x11Display(),
                        x11.XRootWindow(x11Display(), x11.XDefaultScreen(x11Display())),
                        int.min, int.min, 1, 1, 0, 0, 0);
                x11.XSelectInput(x11Display(), clipboardSendWindowHandleX11,
                        SelectionClear | SelectionRequest);
            }
        }

        managed!string clipboardGetContents(IAllocator alloc, Atom property) shared {
            X11WindowProperty value = x11ReadWindowProperty(x11Display(),
                    clipboardReceiveWindowHandleX11, property);

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

final class FreeDesktopNotifications : Feature_NotificationMessage, Feature_NotificationTray {
    Window taskbarSysTrayOwner, taskbarSysTrayWrapper;
    Window[8] wrappersToClean;
    ThreadID[8] wrappersToCleanThreads;
    Visual* theVisual;
    GC taskbarSysTrayGC;
    uint bubbleIdNum;
    bool initialized;

    ~this() {
        // make sure we deallocate before the x11 context does!
        import cf.spew.event_loop.wells.x11;
        assert(x11Display() !is null);

        taskbarTrayWindow = managed!IWindow.init;
    }

    shared(Feature_NotificationTray) __getFeatureNotificationTray() shared {
        return this;
    }

    @property {
        managed!IWindow getNotificationWindow(IAllocator alloc) shared {
            if (cast()taskbarTrayWindow is managed!IWindow.init ||
                    taskbarTrayWindowThread != Thread.getThis().id)
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

    shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared {
        return this;
    }

    void notify(shared(ImageStorage!RGBA8) icon, dstring title, dstring text,
            shared(ISharedAllocator) alloc) shared {
        import std.utf : byChar, codeLength;
        import std.range : drop;

        size_t titleL = title.codeLength!char;
        size_t textL = text.codeLength!char;
        size_t offset;
        bool sentNewLine;

        size_t fullLen = titleL + textL;
        if (title.length > 0 && title[$ - 1] != '\n') {
            fullLen++;
            sentNewLine = true;
        }

        // SYSTEM_TRAY_BEGIN_MESSAGE
        //    l[2] contains the timeout in thousandths of a second or zero for infinite timeout
        //    l[3] contains the length of the message string in bytes, not including any nul bytes
        //    l[4] contains an ID number for the message. This ID number should never be reused by the same tray icon.
        x11SendFreeDesktopSystemTrayMessage(x11Display(), taskbarSysTrayOwner,
                FreeDesktopSystemTray.SYSTEM_TRAY_BEGIN_MESSAGE, 0,
                cast(uint)fullLen, bubbleIdNum);
        bubbleIdNum = bubbleIdNum + 1;

        // _NET_SYSTEM_TRAY_MESSAGE_DATA
        //    must have their window field set to the window ID of the tray icon, and have a format of 8

        offset = 0;
        while (offset < titleL) {
            XEvent ev;
            ev.xclient.type = ClientMessage;
            ev.xclient.window = taskbarSysTrayOwner;
            ev.xclient.message_type = x11Atoms()._NET_SYSTEM_TRAY_MESSAGE_DATA;
            ev.xclient.format = 8;

            size_t offset2;
            foreach (c; title.byChar.drop(offset)) {
                ev.xclient.data.b[offset2++] = c;
                if (offset2 == 20)
                    break;
                offset++;
            }

            if (offset2 < 20 && offset == titleL) {
                ev.xclient.data.b[offset2++] = '\n';
                sentNewLine = true;
            }

            x11.XSendEvent(x11Display(), taskbarSysTrayOwner, False, NoEventMask, &ev);
        }

        offset = 0;
        while (offset < textL) {
            XEvent ev;
            ev.xclient.type = ClientMessage;
            ev.xclient.window = taskbarSysTrayOwner;
            ev.xclient.message_type = x11Atoms()._NET_SYSTEM_TRAY_MESSAGE_DATA;
            ev.xclient.format = 8;

            size_t offset2;

            if (offset == 0 && !sentNewLine) {
                ev.xclient.data.b[offset2++] = '\n';
            }

            foreach (c; text.byChar.drop(offset)) {
                ev.xclient.data.b[offset2++] = c;
                if (offset2 == 20)
                    break;
                offset++;
            }

            x11.XSendEvent(x11Display(), taskbarSysTrayOwner, False, NoEventMask, &ev);
        }
    }

    void clearNotifications() shared {
    }

    package(cf.spew.implementation) {
        void __guardSysTray() shared {
            if (initialized) return;
            initialized = true;

            ThreadID myThreadID = Thread.getThis().id;
            Window trayOwner = x11.XGetSelectionOwner(x11Display(), x11Atoms()._NET_SYSTEM_TRAY_S);

            foreach (i, ref whandle; wrappersToClean) {
                if (whandle == None)
                    continue;
                else if (wrappersToCleanThreads[i] == myThreadID) {
                    x11.XUnmapWindow(x11Display(), whandle);
                    x11.XDestroyWindow(x11Display(), whandle);
                    whandle = None;
                }
            }

            if (taskbarSysTrayWrapper != None && (taskbarTrayWindowThread != myThreadID ||
                    trayOwner != taskbarSysTrayOwner || !haveNotificationWindow())) {

                foreach (i, whandle; wrappersToClean) {
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

                auto systrayVisual = x11ReadWindowProperty(x11Display(),
                        taskbarSysTrayOwner, x11Atoms()._NET_SYSTEM_TRAY_VISUAL);
                XVisualInfo* visualInfo;

                if (systrayVisual.format == 32 && systrayVisual.numberOfItems == 1) {
                    XVisualInfo visualTemplate;
                    visualTemplate.visualid = *cast(VisualID*)systrayVisual.data;
                    int allVisualsCount;

                    visualInfo = x11.XGetVisualInfo(x11Display(), VisualIDMask,
                            &visualTemplate, &allVisualsCount);
                }

                if (visualInfo is null) {
                    theVisual = cast(shared)x11.XDefaultVisual(x11Display(),
                            x11.XDefaultScreen(x11Display()));
                    assert(theVisual !is null);

                    XVisualInfo visualTemplate;
                    visualTemplate.visualid = x11.XVisualIDFromVisual(cast(Visual*)theVisual);
                    int allVisualsCount;

                    visualInfo = x11.XGetVisualInfo(x11Display(), VisualIDMask,
                            &visualTemplate, &allVisualsCount);

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

                    taskbarSysTrayWrapper = x11.XCreateWindow(x11Display(), wroot, 0, 0, size, size, 0, visualInfo.depth,
                            InputOutput, visualInfo.visual,
                            CWBorderPixel | CWColormap | CWBackPixel, &swa);
                    bubbleIdNum = 0;

                    assert(taskbarSysTrayWrapper != None);
                    x11.XFree(visualInfo);
                }

                // backup plan
                if (taskbarSysTrayWrapper == None)
                    taskbarSysTrayWrapper = x11.XCreateSimpleWindow(x11Display(),
                            wroot, 0, 0, size, size, 0, 0, 0xDEFACE00);

                // select
                x11.XSelectInput(x11Display(), taskbarSysTrayOwner, StructureNotifyMask);
                x11.XSelectInput(x11Display(), taskbarSysTrayWrapper,
                        ExposureMask | ButtonPressMask | StructureNotifyMask);

                // dock
                x11SendFreeDesktopSystemTrayMessage(x11Display(), taskbarSysTrayOwner,
                        FreeDesktopSystemTray.SYSTEM_TRAY_REQUEST_DOCK, taskbarSysTrayWrapper, 0, 0);

                // map
                x11.XSync(x11Display(), False);

                // graphics context
                taskbarSysTrayGC = cast(shared)x11.XCreateGC(x11Display(),
                        taskbarSysTrayWrapper, 0, null);
                assert(taskbarSysTrayGC !is null);
            }
        }

        void drawSystray(uint width, uint height, uint* data) shared {
            import core.stdc.stdlib : malloc, free;

            auto attr = x11WindowAttributes(taskbarSysTrayWrapper);

            if (attr.width != width || attr.height != height) {
                uint* temp = cast(uint*)malloc(4 * attr.width * attr.height);

                bilinearInterpolationScale(width, height, attr.width,
                        attr.height, cast(ubyte[4]*)data, cast(ubyte[4]*)temp);

                free(data);
                data = temp;

                width = attr.width;
                height = attr.height;
            }

            XImage* x11Image = x11.XCreateImage(x11Display(), cast(Visual*)taskbarSysTrayGC,
                    24, ZPixmap, 0, cast(char*)data, width, height, 32, 0);
            x11.XPutImage(x11Display(), cast(Window)taskbarSysTrayWrapper,
                    cast(GC)taskbarSysTrayGC, x11Image, 0, 0, 0, 0, attr.width, attr.height);
            x11.XDestroyImage(x11Image);
        }
    }
}

bool checkForX11() {
    import devisualization.bindings.x11;
    import cf.spew.event_loop.wells.x11;

    return x11Display() !is null && x11.XScreenNumberOfScreen !is null &&
        x11.XkbSetDetectableAutoRepeat !is null;
}

