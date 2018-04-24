/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.wells.x11;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import cf.spew.events.windowing;
import stdx.allocator : ISharedAllocator, make;
import devisualization.bindings.x11;

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

private {
	Display* display;
    XIM xim;

	void performInit() {
		if (x11Loader is X11Loader.init) {
			x11Loader = X11Loader(null);
		}

		assert(x11.XOpenDisplay !is null);
		assert(x11.XCloseDisplay !is null);
		assert(x11.XPending !is null);
		assert(x11.XNextEvent !is null);
        assert(x11.XOpenIM !is null);
        assert(x11.XSetLocaleModifiers !is null);

		display = x11.XOpenDisplay(null);

        x11.XSetLocaleModifiers("");
        xim = x11.XOpenIM(display, null, null, null);
        if (!xim) {
            x11.XSetLocaleModifiers("@im=none");
            xim = x11.XOpenIM(display, null, null, null);
        }
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
                if (x11.XFilterEvent(&x11Event, 0)) continue;

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
        // TODO: close atom

        event.wellData1Value = x11Event.xany.window;

        switch(x11Event.type) {
            case MappingNotify:
                if (x11Event.xmapping.request == MappingModifier || x11Event.xmapping.request == MappingKeyboard)
                    x11.XRefreshKeyboardMapping(&x11Event.xmapping);
                break;
            case MapNotify:
            case Expose:
                break;

            case FocusIn:
                auto xic = xicgetdel(x11Event.xany.window);
                if (xic !is null) x11.XSetICFocus(xic);
                break;
            case FocusOut:
                auto xic = xicgetdel(x11Event.xany.window);
                if (xic !is null) x11.XUnsetICFocus(xic);
                break;

            case ConfigureNotify:
                break;
            case ClientMessage:
                break;
            case MotionNotify:
                break;
            case ButtonPress:
                break;
            case ButtonRelease:
                break;
            case KeyPress:
                event.type = Windowing_Events_Types.Window_KeyDown;
                translateKey(x11Event, event, true, xicgetdel);
                break;
            case KeyRelease:
                event.type = Windowing_Events_Types.Window_KeyUp;
                translateKey(x11Event, event, false, xicgetdel);
                break;

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

        if (count == 0 && isPush) {
            // press

            Status status;
            size_t tempIndex;

            count = x11.Xutf8LookupString(xicgetdel(x11Event.xany.window), &x11Event.xkey, c.ptr, 4, &keysym, &status);

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
