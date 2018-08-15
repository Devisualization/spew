module cf.spew.implementation.windowing.utilities.x11;
version (Posix):
import cf.spew.implementation.windowing.display.x11;
import cf.spew.implementation.windowing.window.x11;
import cf.spew.implementation.windowing.utilities.misc;
import cf.spew.event_loop.wells.x11;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.context.defs : IContext;
import devisualization.bindings.x11;
import stdx.allocator : IAllocator, make;
import core.stdc.config : c_ulong, c_long;

struct GetWindows_X11 {
    IAllocator alloc;
    DisplayImpl_X11 display;

    HandleAppender!IWindow windows;

    void call() {
        windows = HandleAppender!IWindow(alloc);
        Window rootWindow = x11.XDefaultRootWindow(x11Display());
        process(rootWindow);
    }

    private void process(Window rootWindow) {
        Window unused1, unused2;
        Window* childWindows;
        uint childCount;

        x11.XQueryTree(x11Display(), rootWindow, &unused1, &unused2,
                &childWindows, &childCount);

        foreach (i; 0 .. childCount) {
            XWindowAttributes attribs;
            x11.XGetWindowAttributes(x11Display(), childWindows[i], &attribs);

            if (display !is null) {
                if ((attribs.x >= display.x && attribs.x < display.x + display.width) &&
                        (attribs.y >= display.y && attribs.y < display.y + display.height)) {
                    // is on this display
                } else
                    continue;
            }

            WindowImpl_X11 window = alloc.make!WindowImpl_X11(childWindows[i],
                    cast(IContext)null, alloc);
            windows.add(window);

            process(childWindows[i]);
        }

        if (childWindows !is null) {
            x11.XFree(childWindows);
        }
    }
}

XWindowAttributes x11WindowAttributes(Window window) {
    int x, y;
    Window unused;
    XWindowAttributes ret;

    Window rootWindow = x11.XDefaultRootWindow(x11Display());
    x11.XTranslateCoordinates(x11Display(), window, rootWindow, 0, 0, &x, &y, &unused);
    x11.XGetWindowAttributes(x11Display(), window, &ret);

    // fixes the coordinates to the correct root instead of parent.
    ret.x = x - ret.x;
    ret.y = y - ret.y;
    return ret;
}

enum {
    XC_watch = 150,
    XC_hand1 = 58,
    XC_left_ptr = 68,
    XC_X_cursor = 0,
    XC_top_left_corner = 134,
    XC_top_right_corner = 136,
    XC_left_side = 70,
    XC_top_side = 138,
    XC_right_side = 196,
    XC_bottom_left_corner = 12,
    XC_bottom_side = 16,
    XC_bottom_right_corner = 14,
    XC_xterm = 152
}

struct X11WindowProperty {
    Atom type;
    int format;
    c_ulong numberOfItems;
    ubyte* data;
}

X11WindowProperty x11ReadWindowProperty(Display* display, Window window, Atom property) {
    c_ulong readByteCount = 1024;
    X11WindowProperty ret;

    while (readByteCount > 0) {
        if (ret.data !is null)
            x11.XFree(ret.data);
        ret.data = null;
        x11.XGetWindowProperty(display, window, property, 0, readByteCount, false,
                AnyPropertyType, &ret.type, &ret.format, &ret.numberOfItems,
                &readByteCount, &ret.data);
    }

    return ret;
}

struct Motif_WMHints {
    c_ulong Flags;
    c_ulong Functions;
    c_ulong Decorations;
    c_long InputMode;
    c_ulong State;
}

// https://people.gnome.org/~tthurman/docs/metacity/xprops_8h.html#1b63c2b33eb9128fd4ec991bf472502e
enum {
    MWM_HINTS_FUNCTIONS = 1 << 0,
    MWM_HINTS_DECORATIONS = 1 << 1,

    MWM_FUNC_ALL = 1 << 0,
    MWM_FUNC_RESIZE = 1 << 1,
    MWM_FUNC_MOVE = 1 << 2,
    MWM_FUNC_MINIMIZE = 1 << 3,
    MWM_FUNC_MAXIMIZE = 1 << 4,

    MWM_DECOR_ALL = 1 << 0,
    MWM_DECOR_BORDER = 1 << 1,
    MWM_DECOR_RESIZEH = 1 << 2,
    MWM_DECOR_TITLE = 1 << 3,
    MWM_DECOR_MENU = 1 << 4,
    MWM_DECOR_MINIMIZE = 1 << 5,
    MWM_DECOR_MAXIMIZE = 1 << 6
}

enum WindowX11Styles : Motif_WMHints {
    Dialog = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
            MWM_FUNC_RESIZE | MWM_FUNC_MOVE | MWM_FUNC_MINIMIZE | MWM_FUNC_MAXIMIZE,
            MWM_DECOR_BORDER | MWM_DECOR_RESIZEH | MWM_DECOR_TITLE |
            MWM_DECOR_MINIMIZE | MWM_DECOR_MAXIMIZE),
    Borderless = Motif_WMHints(
            MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS, MWM_FUNC_MOVE, MWM_DECOR_MINIMIZE | MWM_DECOR_TITLE),
    Popup = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
            MWM_FUNC_MOVE, MWM_DECOR_MINIMIZE | MWM_DECOR_BORDER | MWM_DECOR_TITLE),
    Fullscreen = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
            0, 0),
    NoDecorations = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS, 0, 0),
}

enum FreeDesktopSystemTray {
    SYSTEM_TRAY_REQUEST_DOCK = 0,
    SYSTEM_TRAY_BEGIN_MESSAGE = 1,
    SYSTEM_TRAY_CANCEL_MESSAGE = 2
}

void x11SendFreeDesktopSystemTrayMessage(Display* display, Window tray,
        c_long message, c_long data1, c_long data2, c_long data3) {

    XEvent ev;
    ev.xclient.type = ClientMessage;
    ev.xclient.window = tray;
    ev.xclient.message_type = x11Atoms()._NET_SYSTEM_TRAY_OPCODE;
    ev.xclient.format = 32;
    ev.xclient.data.l[0] = CurrentTime;
    ev.xclient.data.l[1] = message;
    ev.xclient.data.l[2] = data1;
    ev.xclient.data.l[3] = data2;
    ev.xclient.data.l[4] = data3;

    x11.XSendEvent(display, tray, False, NoEventMask, &ev);
    x11.XSync(display, False);
}
