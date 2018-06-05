/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.x11;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import cf.spew.events.windowing;
import cf.spew.events.x11;
import stdx.allocator : ISharedAllocator, make;
import devisualization.bindings.x11;

void setX11ErrorHandler(XErrorHandler handler=null) {
    if (handler is null)
        handler = &defaultX11ErrorHandler;
    x11.XSetErrorHandler(handler);
}

Display* x11Display() {
    if (display is null)
        performInit();
    assert(display !is null);
    return display;
}

XIM x11XIM() {
    x11Display();
    return xim;
}

X11Atoms x11Atoms() {
    x11Display();
    return atoms;
}

struct X11Atoms {
    Atom
        XdndEnter,
        XdndPosition,
        XdndStatus,
        XdndTypeList,
        XdndActionCopy,
        XdndDrop,
        XdndLeave,
        XdndFinished,
        XdndSelection,
        XdndProxy,
        XdndAware,

        CARDINAL,
        XA_ATOM,
        XA_TARGETS,
        INTEGER,
        UTF8_STRING,

        Backlight,
        BACKLIGHT,

        PRIMARY,
        CLIPBOARD,

        WM_DELETE_WINDOW,
        _NET_WM_ICON,
        _MOTIF_WM_HINTS,
        _NET_WM_ALLOWED_ACTIONS,
        _NET_WM_STATE,

        _NET_WM_WINDOW_TYPE_NORMAL,
        _NET_WM_WINDOW_TYPE_UTILITY,

        _NET_WM_STATE_STICKY,
        _NET_WM_STATE_MODAL,
        _NET_WM_STATE_ABOVE,
        _NET_WM_STATE_FULLSCREEN,

        _NET_WM_ACTION_FULLSCREEN,
        _NET_WM_ACTION_CLOSE,
        _NET_WM_ACTION_MINIMIZE,
        _NET_WM_ACTION_RESIZE,
        _NET_WM_ACTION_MOVE,
        _NET_WM_ACTION_ABOVE,
        _NET_WM_ACTION_MAXIMIZE_HORZ,
        _NET_WM_ACTION_MAXIMIZE_VERT;
}

private {
    Display* display;
    XIM xim;
    X11Atoms atoms;

    void performInit() {
        if (x11Loader is X11Loader.init) {
            x11Loader = X11Loader(null);
            setX11ErrorHandler(null);
        }

        assert(x11.XOpenDisplay !is null);
        assert(x11.XCloseDisplay !is null);
        assert(x11.XPending !is null);
        assert(x11.XNextEvent !is null);
        assert(x11.XOpenIM !is null);
        assert(x11.XSetLocaleModifiers !is null);
        assert(x11.XInternAtom !is null);

        display = x11.XOpenDisplay(null);

        x11.XSetLocaleModifiers("");
        xim = x11.XOpenIM(display, null, null, null);
        if (!xim) {
            x11.XSetLocaleModifiers("@im=none");
            xim = x11.XOpenIM(display, null, null, null);
        }

        static foreach(m; __traits(allMembers, X11Atoms)) {
            mixin("atoms." ~ m ~ " = x11.XInternAtom(x11Display(), cast(char*)\"" ~ m ~ "\".ptr, false);");
        }

        atoms.XA_ATOM = x11.XInternAtom(x11Display(), cast(char*)"ATOM".ptr, false);
        atoms.XA_TARGETS = x11.XInternAtom(x11Display(), cast(char*)"TARGETS".ptr, false);
    }

    extern(C) int defaultX11ErrorHandler(Display* d, XErrorEvent* err) {
        import std.stdio : stderr;

        debug {
            import core.stdc.string : strlen;
            char[1024] buffer;
            x11.XGetErrorText(d, err.error_code, buffer.ptr, cast(int)buffer.length);
            stderr.writeln("X11 Error: ", buffer[0 .. strlen(buffer.ptr)]);
        } else {
            stderr.writeln("X11 error");
        }

        stderr.flush;
        return 0;
    }

    static ~this() {
        if (display !is null)
            x11.XCloseDisplay(display);
    }
}

alias X11GetXICDel = shared XIC delegate(Window);

final class X11EventLoopSource : EventLoopSource {
    import cf.spew.event_loop.known_implementations;

    X11GetXICDel xicgetdel;

    this(X11GetXICDel xicgetdel) shared {
        this.xicgetdel = xicgetdel;
    }

    @property {
        bool onMainThread() shared { return true; }
        bool onAdditionalThreads() shared { return true; }
        string description() shared { return "Implements support for a X11 based event loop iteration. Singleton but threaded."; }
        EventSource identifier() shared { return EventSources.X11; }
    }

    shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator) alloc) shared {
        if (display is null)
            performInit();

        return alloc.make!(shared(X11EventLoopSourceRetrieve))(xicgetdel);
    }
}

final class X11EventLoopSourceRetrieve : EventLoopSourceRetriever {
    import cf.spew.event_loop.known_implementations;
    import core.time : dur, Duration;

    X11GetXICDel xicgetdel;

    this(X11GetXICDel xicgetdel) shared {
        this.xicgetdel = xicgetdel;
    }

    bool nextEvent(ref Event event) shared {
        event.source = EventSources.X11;
        // prevents any searching for a consumer (no event actually returned)
        event.type.value = 0;

        for(;;) {
            int pending = x11.XPending(display);
            if (pending > 0) {
                XEvent x11Event;
                x11.XPeekEvent(display, &x11Event);

                x11.XNextEvent(display, &x11Event);
                //if (x11.XFilterEvent(&x11Event, 0)) continue;

                processEvent(x11Event, event, xicgetdel);
                return true;
            } else
                return false;
        }
    }

    void handledEvent(ref Event event) shared {}
    void unhandledEvent(ref Event event) shared {}
    void handledErrorEvent(ref Event event) shared {}
    void hintTimeout(Duration timeout) shared {}
}

private {
    void processEvent(ref XEvent x11Event, ref Event event, X11GetXICDel xicgetdel) {
        event.wellData1Value = x11Event.xany.window;

        switch(x11Event.type) {
            case MappingNotify:
                if (x11Event.xmapping.request == MappingModifier || x11Event.xmapping.request == MappingKeyboard)
                    x11.XRefreshKeyboardMapping(&x11Event.xmapping);
                break;
            case MapNotify:
            case Expose:
                event.type = X11_Events_Types.Expose;
                break;

            case FocusIn:
                auto xic = xicgetdel(x11Event.xany.window);
                if (xic !is null) x11.XSetICFocus(xic);
                event.type = Windowing_Events_Types.Window_Focused;
                break;
            case FocusOut:
                auto xic = xicgetdel(x11Event.xany.window);
                if (xic !is null) x11.XUnsetICFocus(xic);
                break;

            case ConfigureNotify:
                event.type = X11_Events_Types.NewSizeLocation;
                event.x11.configureNotify.x = x11Event.xconfigure.x;
                event.x11.configureNotify.y = x11Event.xconfigure.y;
                event.x11.configureNotify.width = x11Event.xconfigure.width;
                event.x11.configureNotify.height = x11Event.xconfigure.height;
                break;
            case ClientMessage:
                if (atoms.WM_DELETE_WINDOW != 0 && x11Event.xclient.format == 32 && x11Event.xclient.data.l[0] == atoms.WM_DELETE_WINDOW) {
                    event.type = Windowing_Events_Types.Window_RequestClose;
                } else if ((atoms.XdndEnter != None && x11Event.xclient.message_type == atoms.XdndEnter) ||
                            (atoms.XdndPosition != None && x11Event.xclient.message_type == atoms.XdndPosition) ||
                            (atoms.XdndDrop != None && x11Event.xclient.message_type == atoms.XdndDrop) ||
                            (atoms.XdndLeave != None && x11Event.xclient.message_type == atoms.XdndLeave)) {

                    event.type = X11_Events_Types.Raw;
                    event.x11.raw = x11Event;
                }
                break;
            case SelectionNotify:
                if (x11Event.xselection.property != None) {
                    event.type = X11_Events_Types.Raw;
                    event.x11.raw = x11Event;
                }

                break;
            case MotionNotify:
                event.type = Windowing_Events_Types.Window_CursorMoved;
                event.windowing.cursorMoved.newX = x11Event.xmotion.x;
                event.windowing.cursorMoved.newY = x11Event.xmotion.y;
                break;
            case ButtonPress:
                if (x11Event.xbutton.button == Button4) {
                    event.type = Windowing_Events_Types.Window_CursorScroll;
                    event.windowing.scroll.amount = 1;
                    event.windowing.scroll.x = x11Event.xbutton.x;
                    event.windowing.scroll.y = x11Event.xbutton.y;
                } else if (x11Event.xbutton.button == Button5) {
                    event.type = Windowing_Events_Types.Window_CursorScroll;
                    event.windowing.scroll.amount = -1;
                    event.windowing.scroll.x = x11Event.xbutton.x;
                    event.windowing.scroll.y = x11Event.xbutton.y;
                } else {
                    event.type = Windowing_Events_Types.Window_CursorAction;
                    event.windowing.cursorAction.x = x11Event.xbutton.x;
                    event.windowing.cursorAction.y = x11Event.xbutton.y;
                    event.windowing.cursorAction.isDoubleClick = false;

                    if (x11Event.xbutton.button == Button1)
                        event.windowing.cursorAction.action = CursorEventAction.Select;
                    else if (x11Event.xbutton.button == Button2)
                        event.windowing.cursorAction.action = CursorEventAction.ViewChange;
                    else if (x11Event.xbutton.button == Button3)
                        event.windowing.cursorAction.action = CursorEventAction.Alter;
                }
                break;
            case ButtonRelease:
                event.type = Windowing_Events_Types.Window_CursorActionEnd;
                event.windowing.cursorAction.x = x11Event.xbutton.x;
                event.windowing.cursorAction.y = x11Event.xbutton.y;
                event.windowing.cursorAction.isDoubleClick = false;

                if (x11Event.xbutton.button == Button1)
                    event.windowing.cursorAction.action = CursorEventAction.Select;
                else if (x11Event.xbutton.button == Button2)
                    event.windowing.cursorAction.action = CursorEventAction.ViewChange;
                else if (x11Event.xbutton.button == Button3)
                    event.windowing.cursorAction.action = CursorEventAction.Alter;
                else
                    event.type = 0;
                break;
            case KeyPress:
                event.type = Windowing_Events_Types.Window_KeyDown;
                translateKey(x11Event, event, true, xicgetdel);
                break;
            case KeyRelease:
                event.type = Windowing_Events_Types.Window_KeyUp;
                translateKey(x11Event, event, false, xicgetdel);
                break;

            case DestroyNotify:
                event.type = X11_Events_Types.DestroyNotify;
            default:
                break;
        }
    }

    void translateKey(ref XEvent x11Event, ref Event event, bool isPush, X11GetXICDel xicgetdel) {
        import cf.spew.events.windowing;
        import std.utf : decode;

        char[4] c;
        KeySym keysym;
        int count = x11.XLookupString(&x11Event.xkey, c.ptr, 1, &keysym, null);

        if ((x11Event.xkey.state & Mod1Mask) == Mod1Mask)
            event.windowing.keyInput.modifiers |= KeyModifiers.Alt;
        if ((x11Event.xkey.state & ControlMask) == ControlMask)
            event.windowing.keyInput.modifiers |= KeyModifiers.Control;
        if ((x11Event.xkey.state & ShiftMask) == ShiftMask)
            event.windowing.keyInput.modifiers |= KeyModifiers.Shift;
        if ((x11Event.xkey.state & LockMask) == LockMask)
            event.windowing.keyInput.modifiers |= KeyModifiers.Capslock;
        if ((x11Event.xkey.state & Mod4Mask) == Mod4Mask)
            event.windowing.keyInput.modifiers |= KeyModifiers.Super;

        switch(keysym) {
            case XK_KP_Enter:
                event.windowing.keyInput.modifiers |= KeyModifiers.Numlock;
                event.windowing.keyInput.special = SpecialKey.Enter;
                return;
            case XK_KP_Add:
            case XK_KP_Subtract:
            case XK_KP_Multiply:
            case XK_KP_Divide:
            case XK_KP_Decimal:
            case XK_KP_0: .. case XK_KP_9:
                event.windowing.keyInput.modifiers |= KeyModifiers.Numlock;
                event.windowing.keyInput.key = c[0];
                return;

            default:
                break;

        }

        auto xic = xicgetdel(x11Event.xany.window);
        if (count == 0 && isPush && xic !is null) {
            // press

            Status status;
            size_t tempIndex;

            count = x11.Xutf8LookupString(xic, &x11Event.xkey, c.ptr, 4, &keysym, &status);

            if (status == XLookupChars) {
                event.type = Windowing_Events_Types.Window_KeyInput;
                event.windowing.keyInput.key = decode(c[0 .. count], tempIndex);
            } else if (status == XLookupBoth || status == XLookupKeySym) {
                import core.stdc.string : strlen;

                char* syn_name = x11.XKeysymToString(keysym);
                size_t synlen = strlen(syn_name);

                if (synlen > 0) {
                    event.type = Windowing_Events_Types.Window_KeyInput;
                    event.windowing.keyInput.key = decode(syn_name[0 .. synlen], tempIndex);
                }
            }

        } else if (count > 0) {
            // down
            event.windowing.keyInput.key = c[0];
        }

        switch(keysym) {
            case XK_Escape:
                event.windowing.keyInput.special = SpecialKey.Escape;
                return;

            case XK_Return:
                event.windowing.keyInput.special = SpecialKey.Enter;
                return;

            case XK_BackSpace:
                event.windowing.keyInput.special = SpecialKey.Backspace;
                return;
            case XK_Tab:
                event.windowing.keyInput.special = SpecialKey.Tab;
                return;

            case XK_Prior:
                event.windowing.keyInput.special = SpecialKey.PageUp;
                break;
            case XK_Next:
                event.windowing.keyInput.special = SpecialKey.PageDown;
                break;

            case XK_End:
                event.windowing.keyInput.special = SpecialKey.End;
                break;
            case XK_Home:
                event.windowing.keyInput.special = SpecialKey.Home;
                break;
            case XK_Insert:
                event.windowing.keyInput.special = SpecialKey.Insert;
                break;
            case XK_Delete:
                event.windowing.keyInput.special = SpecialKey.Delete;
                break;

            case XK_Left:
                event.windowing.keyInput.special = SpecialKey.LeftArrow;
                break;
            case XK_Right:
                event.windowing.keyInput.special = SpecialKey.RightArrow;
                break;
            case XK_Up:
                event.windowing.keyInput.special = SpecialKey.UpArrow;
                break;
            case XK_Down:
                event.windowing.keyInput.special = SpecialKey.DownArrow;
                break;

            case XK_Scroll_Lock:
                event.windowing.keyInput.special = SpecialKey.ScrollLock;
                break;

            case XK_F1: .. case XK_F24:
                event.windowing.keyInput.special = cast(SpecialKey)(SpecialKey.F1 + (keysym - XK_F1));
                return;

            default:
                break;
        }
    }
}

