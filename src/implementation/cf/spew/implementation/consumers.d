/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.consumers;
public import cf.spew.ui;
public import cf.spew.miscellaneous.timer;
public import cf.spew.event_loop;
public import cf.spew.events;
public import devisualization.image : ImageStorage;
public import std.experimental.color : RGB8, RGBA8;
public import std.experimental.containers.list;
public import std.experimental.containers.map;
public import stdx.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
public import devisualization.util.core.memory.managed;

abstract class EventLoopConsumerImpl : EventLoopConsumer {
    import cf.spew.events.windowing;
    import cf.spew.implementation.windowing.window;
    import cf.spew.implementation.instance;
    import std.typecons : Nullable;

    shared(DefaultImplementation) instance;
    shared(UIInstance) uiInstance;
	
    this(shared(DefaultImplementation) instance) shared {
        this.instance = instance;
        this.uiInstance = cast(shared(UIInstance))instance.ui;
    }
	
    bool processEvent(ref Event event) shared {
        // umm shouldn't we check that you know this is a windowing event?
        IWindow window = cast()uiInstance.windowToIdMapper[event.wellData1Value];
    	
        if (window is null) {
        } else if (WindowImpl w = cast(WindowImpl)window) {
            switch(event.type) {
                case Windowing_Events_Types.Window_Moved:
                    tryFunc(w.onMoveDel, event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
                    return true;
                case Windowing_Events_Types.Window_Resized:
                    tryFunc(w.onSizeChangeDel, event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
                    return true;
                case Windowing_Events_Types.Window_CursorScroll:
                    tryFunc(w.onScrollDel, event.windowing.scroll.amount);
                    return true;
                case Windowing_Events_Types.Window_CursorMoved:
                    tryFunc(w.onCursorMoveDel, event.windowing.cursorMoved.newX, event.windowing.cursorMoved.newY);
                    return true;
                case Windowing_Events_Types.Window_CursorAction:
                    tryFunc(w.onCursorActionDel, event.windowing.cursorAction.action);
                    return true;
                case Windowing_Events_Types.Window_CursorActionEnd:
                    tryFunc(w.onCursorActionEndDel, event.windowing.cursorAction.action);
                    return true;

                case Windowing_Events_Types.Window_KeyInput:
                case Windowing_Events_Types.Window_KeyUp:
                    tryFunc(w.onKeyEntryDel, event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
                    return true;

                case Windowing_Events_Types.Window_CursorActionDo:
                case Windowing_Events_Types.Window_KeyDown:
                default:
                    return false;
            }
        }
    	
        return false;
    }
	
    @property {
        Nullable!EventSource pairOnlyWithSource() shared { return Nullable!EventSource(); }
    	
        EventType pairOnlyWithEvents() shared { return EventType.all; }
    	
        byte priority() shared { return byte.max / 2; }
    	
        string description() shared { return "Default implementation consumer for Windowing."; }
    }
}

private {
    import std.traits : ReturnType;

    void tryFunc(T, U...)(T func, U args) if (is(ReturnType!T == void)) {
        if (func !is null) {
            try {
                func(args);
            } catch(Exception e) {
            }
        }
    }

    J tryFunc(T, J=ReturnType!T, U...)(T func, J default_, U args) if (!is(ReturnType!T == void)) {
        if (func !is null) {
            try {
                return func(args);
            } catch(Exception e) {}
        }
    	
        return default_;
    }
}

version(Windows) {
    public import winapi = core.sys.windows.windows;

    final class EventLoopConsumerImpl_WinAPI : EventLoopConsumerImpl {
        import cf.spew.implementation.instance;
        import cf.spew.implementation.windowing.window;
        import cf.spew.implementation.misc.timer;
        import cf.spew.events.windowing;
        import cf.spew.events.winapi;
    	
        this(shared(DefaultImplementation) instance) shared {
            super(instance);
        }
    	
        override bool processEvent(ref Event event) shared {
            IWindow window = cast()uiInstance.windowToIdMapper[event.wellData1Value];

            if (window is null) {
                ITimer timer = cast()this.instance._miscInstance.timerToIdMapper[event.wellData1Value];

                if (timer is null) {
                } else {
                    switch(event.type) {
                        case Windowing_Events_Types.Window_RequestClose:
                            timer.stop();
                            return true;

                        case WinAPI_Events_Types.Window_Timer:
                            if (TimerImpl timer2 = cast(TimerImpl)timer) {
                                tryFunc(timer2.onEventDel, timer);
                            }
                            return true;
                        default:
                            return false;
                    }
                }
            } else if (WindowImpl_WinAPI w = cast(WindowImpl_WinAPI)window) {
                WindowImpl w2 = cast(WindowImpl)w;

                switch(event.type) {
                    case Windowing_Events_Types.Window_Resized:
                        winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
                        tryFunc(w2.onSizeChangeDel, event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
                        return true;
                    case Windowing_Events_Types.Window_Moved:
                        winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
                        tryFunc(w2.onMoveDel, event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
                        return true;
                    case Windowing_Events_Types.Window_Focused:
                        if (winapi.LOWORD(event.wellData2Value) == 0) {
                        } else {
                            if (w.oldCursorClipArea != winapi.RECT.init)
                                w.lockCursorToWindow;
                        }
                        return true;
                    case Windowing_Events_Types.Window_CursorScroll:
                        tryFunc(w.onScrollDel, event.windowing.scroll.amount / 120);
                        return true;

                    case WinAPI_Events_Types.Window_Quit:
                        return false;
                    case WinAPI_Events_Types.Window_GainedKeyboardFocus:
                        return false;
                    case WinAPI_Events_Types.Window_LostKeyboardFocus:
                        return false;
                    case WinAPI_Events_Types.Window_Enable:
                        return false;
                    case WinAPI_Events_Types.Window_Disable:
                        return false;
                    case WinAPI_Events_Types.Window_SetRedraw:
                        return false;
                	
                    case WinAPI_Events_Types.Window_Paint:
                        return handlePaint(event, w, w2);
                    case WinAPI_Events_Types.Window_SystemColorsChanged:
                        return false;
                    case WinAPI_Events_Types.Window_DevModeChanged:
                        return false;
                    case WinAPI_Events_Types.Window_SetCursor:
                        if (winapi.LOWORD(event.wellData2Value) == winapi.HTCLIENT && w.cursorStyle != WindowCursorStyle.Underterminate) {
                            winapi.SetCursor(w.hCursor);
                            return true;
                        }
                        return false;
                    case WinAPI_Events_Types.Window_EnterSizeMove:
                        return false;
                    case WinAPI_Events_Types.Window_ExitSizeMove:
                        winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
                        return true;
                    case Windowing_Events_Types.Window_RequestClose:
                        if (tryFunc(w2.onRequestCloseDel, true)) {
                            winapi.DestroyWindow(event.wellData1Ptr);
                        }
                        return true;
                    case WinAPI_Events_Types.Menu_Click:
                        tryFunc(w.menuCallbacks[event.wellData2Value], w.menuItemsIds[event.wellData2Value]);
                        return true;

                    case WinAPI_Events_Types.Window_DragAndDrop:
                        import std.utf : byChar, codeLength;
                        import core.sys.windows.windows;

                        HDROP hdrop = cast(HDROP)event.wellData2Ptr;
                        POINT point;
                        DragQueryPoint(hdrop, &point);

                        auto alloc = w2.allocator();
                        wchar[] buffer1 = alloc.makeArray!wchar(256);
                        char[] buffer2 = alloc.makeArray!char(256);

                        size_t count, len1, len2;
                        while((len1 = DragQueryFileW(hdrop, cast(uint)count, null, 0)) != 0) {
                            if (buffer1.length < len1) {
                                alloc.expandArray(buffer1, len1-buffer1.length);
                            }

                            DragQueryFileW(hdrop, cast(uint)count++, buffer1.ptr, cast(uint)buffer1.length);

                            len2 = codeLength!char(buffer1[0 .. len1]);
                            if (buffer2.length < len2) {
                                alloc.expandArray(buffer2, len2-buffer2.length);
                            }

                            size_t offset;
                            foreach(c; buffer1[0 .. len1].byChar) {
                                buffer2[offset++] = c;
                            }

                            if (w2.onFileDropDel !is null) {
                                try {
                                    w2.onFileDropDel(cast(string)buffer2[0 .. len2], point.x, point.y);
                                } catch(Exception e) {}
                            }
                        }

                        alloc.dispose(buffer1);
                        alloc.dispose(buffer2);

                        DragFinish(hdrop);
                        return true;

                    case Windowing_Events_Types.Window_KeyUp:
                        tryFunc(w2.onKeyEntryDel, event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
                        tryFunc(w2.onKeyReleaseDel, event.windowing.keyUp.key, event.windowing.keyUp.special, event.windowing.keyUp.modifiers);
                        return true;
                    case Windowing_Events_Types.Window_KeyDown:
                        tryFunc(w2.onKeyPressDel, event.windowing.keyDown.key, event.windowing.keyDown.special, event.windowing.keyDown.modifiers);
                        return true;

                    default:
                        if (event.type == WinAPI_Events_Types.Raw) {
                            if (event.winapi.raw.message == winapi.WM_ERASEBKGND) {
                                return handlePaint(event, w, w2);
                            }
                        }
                        break;
                }
            }

            if (super.processEvent(event))
                return true;
            else
                return false;
        }

        @property {
            override Nullable!EventSource pairOnlyWithSource() shared { return Nullable!EventSource(EventSources.WinAPI); }
            bool onMainThread() shared { return true; }
            bool onAdditionalThreads() shared { return true; }
        }

        bool handlePaint(ref Event event, WindowImpl_WinAPI w, WindowImpl w2) shared {
            winapi.ValidateRgn(event.wellData1Ptr, null);

            if (w2.context_ is null) {
                winapi.PAINTSTRUCT ps;
                winapi.HDC hdc = winapi.BeginPaint(event.wellData1Ptr, &ps);
                winapi.FillRect(hdc, &ps.rcPaint, cast(winapi.HBRUSH) (winapi.COLOR_WINDOW+1));
                winapi.EndPaint(event.wellData1Ptr, &ps);
            } else if (w2.onDrawDel is null) {
                w2.context.activate;
                w2.context.deactivate;
            } else {
                tryFunc(w2.onDrawDel);
            }

            return true;
        }
    }
}

class EventLoopConsumerImpl_X11 : EventLoopConsumerImpl {
    import cf.spew.events.windowing;
    import cf.spew.implementation.windowing.window;
    import cf.spew.implementation.windowing.misc;
    import cf.spew.implementation.instance;
    import cf.spew.events.x11;
    import cf.spew.event_loop.wells.x11;
    import x11b = devisualization.bindings.x11;
    import std.typecons : Nullable;

    this(shared(DefaultImplementation) instance) shared {
        super(instance);
    }

    @property {
        override Nullable!EventSource pairOnlyWithSource() shared { return Nullable!EventSource(EventSources.X11); }
        bool onMainThread() shared { return true; }
        bool onAdditionalThreads() shared { return true; }
    }

    override bool processEvent(ref Event event) shared {
        import core.stdc.string : strlen;

        if (event.wellData1Value == clipboardSendWindowHandleX11) {
            if (event.type == X11_Events_Types.Raw) {
                x11b.XEvent x11Event = event.x11.raw;
                switch(x11Event.type) {
                    case x11b.SelectionClear:
                        clipboardDataAllocator.dispose(clipboardSendData);
                        break;
                    case x11b.SelectionRequest:
                        x11b.XSelectionRequestEvent* ser = &x11Event.xselectionrequest;

                        if (ser.target != x11Atoms().UTF8_STRING || ser.property == x11b.None || clipboardSendData.length == 0) {
                            x11b.XSelectionEvent ret;
                            ret.type = x11b.SelectionNotify;
                            ret.requestor = ser.requestor;
                            ret.selection = ser.selection;
                            ret.target = ser.target;
                            ret.property = x11b.None;
                            ret.time = ser.time;

                            x11b.x11.XSendEvent(x11Display(), ser.requestor, x11b.True, x11b.NoEventMask, cast(x11b.XEvent*)&ret);
                        } else {
                            x11b.x11.XChangeProperty(x11Display(), ser.requestor, ser.property, x11Atoms().UTF8_STRING, 8, x11b.PropModeReplace, cast(ubyte*)clipboardSendData.ptr, cast(int)clipboardSendData.length);

                            x11b.XSelectionEvent ret;
                            ret.type = x11b.SelectionNotify;
                            ret.requestor = ser.requestor;
                            ret.selection = ser.selection;
                            ret.target = ser.property;
                            ret.time = ser.time;
                            x11b.x11.XSendEvent(x11Display(), ser.requestor, x11b.True, x11b.NoEventMask, cast(x11b.XEvent*)&ser);
                        }
                        break;
                    default:
                        break;
                }
            }
        } else {
            IWindow window = cast()uiInstance.windowToIdMapper[event.wellData1Value];

            if (WindowImpl_X11 w = cast(WindowImpl_X11)window) {
                WindowImpl w2 = cast(WindowImpl)w;

                switch(event.type) {
                    case Windowing_Events_Types.Window_KeyUp:
                        tryFunc(w2.onKeyEntryDel, event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
                        tryFunc(w2.onKeyReleaseDel, event.windowing.keyUp.key, event.windowing.keyUp.special, event.windowing.keyUp.modifiers);
                        return true;
                    case Windowing_Events_Types.Window_KeyDown:
                        tryFunc(w2.onKeyPressDel, event.windowing.keyDown.key, event.windowing.keyDown.special, event.windowing.keyDown.modifiers);
                        return true;

                    case Windowing_Events_Types.Window_RequestClose:
                        if (tryFunc(w2.onRequestCloseDel, true)) {
                            w.close();
                        }
                        return true;

                    case X11_Events_Types.NewSizeLocation:
                        Event temp;
                        if (w.lastX != event.x11.configureNotify.x || w.lastY != event.x11.configureNotify.y) {
                            w.lastX = event.x11.configureNotify.x;
                            w.lastY = event.x11.configureNotify.y;

                            temp = event;
                            temp.type = Windowing_Events_Types.Window_Moved;
                            temp.windowing.windowMoved.newX = w.lastX;
                            temp.windowing.windowMoved.newY = w.lastY;
                            return super.processEvent(temp);
                        }
                        if (w.lastWidth != event.x11.configureNotify.width || w.lastHeight != event.x11.configureNotify.height) {
                            w.lastWidth = event.x11.configureNotify.width;
                            w.lastHeight = event.x11.configureNotify.height;

                            temp = event;
                            temp.type = Windowing_Events_Types.Window_Resized;
                            temp.windowing.windowResized.newWidth = w.lastWidth;
                            temp.windowing.windowResized.newHeight = w.lastHeight;
                            return super.processEvent(temp);
                        }
                        return true;
                    case Windowing_Events_Types.Window_Focused:
                        return true;
                    case X11_Events_Types.Expose:
                        return handlePaint(event, w, w2);
                    case X11_Events_Types.DestroyNotify:
                        tryFunc(w2.onCloseDel);
                        return true;

                    default:
                        if (event.type == X11_Events_Types.Raw) {
                            x11b.XEvent x11Event = event.x11.raw;

                            switch(x11Event.type) {
                                case x11b.ClientMessage:
                                    if (x11Event.xclient.message_type == x11Atoms().XdndEnter) {
                                        bool moreThanThreeTypes = (x11Event.xclient.data.l[1] & 1) == 1;
                                        w.xdndSourceWindow = cast(x11b.Window)x11Event.xclient.data.l[0];
                                        w.xdndToBeRequested = x11b.None;

                                        if (moreThanThreeTypes) {
                                            X11WindowProperty property = x11ReadWindowProperty(x11Display(), w.xdndSourceWindow, x11Atoms().XdndTypeList);
                                            if (property.type == x11Atoms().XA_ATOM)
                                                w.xdndToBeRequested = chooseAtomXDND(x11Display(), (cast(x11b.Atom*)property.data)[0 .. property.numberOfItems]);
                                            x11b.x11.XFree(property.data);
                                        } else {
                                            x11b.Atom[3] listOfAtoms = [cast(x11b.Atom)x11Event.xclient.data.l[2], x11Event.xclient.data.l[3], x11Event.xclient.data.l[4]];
                                            w.xdndToBeRequested = chooseAtomXDND(x11Display(), listOfAtoms[]);
                                        }

                                        tryFunc(w2.onFileDragStartDel);
                                    } else if (x11Event.xclient.message_type == x11Atoms().XdndPosition) {
                                        x11b.Window _1, _2;
                                        int _3, _4, x, y;
                                        uint _5;

                                        x11b.x11.XQueryPointer(x11Display(), w.whandle, &_1, &_2, &_3, &_4, &x, &y, &_5);
                                        bool canDrop = tryFunc(w2.onFileDraggingDel, false, x, y);

                                        x11b.XClientMessageEvent message;
                                        message.type = x11b.ClientMessage;
                                        message.display = x11Event.xclient.display;
                                        message.window = x11Event.xclient.data.l[0];
                                        message.message_type = x11Atoms().XdndStatus;
                                        message.format = 32;
                                        message.data.l[0] = w.whandle;
                                        message.data.l[1] = canDrop && w.xdndToBeRequested != x11b.None;
                                        message.data.l[4] = x11Atoms().XdndActionCopy;

                                        x11b.x11.XSendEvent(x11Display(), x11Event.xclient.data.l[0], x11b.False, x11b.NoEventMask, cast(x11b.XEvent*)&message);
                                        x11b.x11.XFlush(x11Display());
                                    } else if (x11Event.xclient.message_type == x11Atoms().XdndLeave) {
                                        tryFunc(w2.onFileDragStopDel);
                                    } else if (x11Event.xclient.message_type == x11Atoms().XdndDrop) {
                                        if (w.xdndToBeRequested == x11b.None) {
                                            x11b.XClientMessageEvent message;
                                            message.type = x11b.ClientMessage;
                                            message.display = x11Event.xclient.display;
                                            message.window = x11Event.xclient.data.l[0];
                                            message.message_type = x11Atoms().XdndFinished;
                                            message.format = 32;
                                            message.data.l[0] = w.whandle;
                                            message.data.l[2] = x11b.None;

                                            x11b.x11.XSendEvent(x11Display(), x11Event.xclient.data.l[0], x11b.False, x11b.NoEventMask, cast(x11b.XEvent*)&message);
                                        } else {
                                            x11b.x11.XConvertSelection(x11Display(), x11Atoms().XdndSelection, w.xdndToBeRequested, x11Atoms().PRIMARY, w.whandle, x11Event.xclient.data.l[2]);
                                        }
                                    }
                                    break;

                                case x11b.SelectionNotify:
                                    if (!w.supportsXDND)
                                        break;

                                    x11b.Atom target = x11Event.xselection.target;
                                    X11WindowProperty property = x11ReadWindowProperty(x11Display(), w.whandle, x11Atoms().PRIMARY);

                                    if (target == x11Atoms().XA_TARGETS) {
                                        X11WindowProperty propertyTL = x11ReadWindowProperty(x11Display(), w.xdndSourceWindow, x11Atoms().XdndTypeList);

                                        if (propertyTL.type == x11Atoms().XA_ATOM) {
                                            w.xdndToBeRequested = chooseAtomXDND(x11Display(), (cast(x11b.Atom*)propertyTL.data)[0 .. propertyTL.numberOfItems]);
                                            if (w.xdndToBeRequested != x11b.None) {
                                                x11b.x11.XConvertSelection(x11Display(), x11Atoms().XdndSelection, w.xdndToBeRequested, x11Atoms().PRIMARY, w.whandle, x11Event.xclient.data.l[2]);
                                            }
                                        }
                                        x11b.x11.XFree(propertyTL.data);
                                    } else if (target == w.xdndToBeRequested) {
                                        char* str = cast(char*)property.data;
                                        string text = cast(string)str[0 .. strlen(str)];

                                        x11b.Window queryPointer1, queryPointer2;
                                        int x, y, queryPointer3, queryPointer4;
                                        uint queryPointer5;
                                        x11b.x11.XQueryPointer(x11Display(), w.whandle, &queryPointer1, &queryPointer2, &queryPointer3, &queryPointer4, &x, &y, &queryPointer5);

                                        bool canDrop = tryFunc(w2.onFileDraggingDel, false, x, y);
                                        if (canDrop) {
                                            size_t start;
                                            foreach(i, c; text) {
                                                if (c == '\n') {
                                                    tryFunc(w2.onFileDropDel, text[start .. i], x, y);
                                                    start = i + 1;
                                                }
                                            }

                                            if (start < text.length)
                                                tryFunc(w2.onFileDropDel, text[start .. $], x, y);
                                        }

                                        tryFunc(w2.onFileDragStopDel);

                                        x11b.XClientMessageEvent message;
                                        message.type = x11b.ClientMessage;
                                        message.display = x11Display();
                                        message.window = w.xdndSourceWindow;
                                        message.message_type = x11Atoms().XdndFinished;
                                        message.format = 32;
                                        message.data.l[0] = w.whandle;
                                        message.data.l[1] = 1;
                                        message.data.l[2] = x11Atoms().XdndActionCopy;

                                        x11b.x11.XSendEvent(x11Display(), w.xdndSourceWindow, x11b.False, x11b.NoEventMask, cast(x11b.XEvent*)&message);

                                        x11b.x11.XDeleteProperty(x11Display(), w.whandle, x11Atoms().PRIMARY);
                                        x11b.x11.XSync(x11Display(), false);
                                    }

                                    if (property.data !is null)
                                        x11b.x11.XFree(property.data);

                                    break;
                                default:
                                    break;
                            }
                        }
                        break;
                }
            }
        }

        if (super.processEvent(event))
            return true;
        else
            return false;
    }

    final bool handlePaint(ref Event event, WindowImpl_X11 w, WindowImpl w2) shared {
        if (w2.context_ is null) {
            // TODO: draw manually
        } else if (w2.onDrawDel is null) {
            w2.context.activate;
            w2.context.deactivate;
        } else {
            tryFunc(w2.onDrawDel);
        }
        return true;
    }

    final x11b.Atom chooseAtomXDND(x11b.Display* display, x11b.Atom[] atoms) shared {
        import core.stdc.string : strlen;
        x11b.Atom ret = x11b.None;

        if (x11b.x11.XGetAtomName !is null) {
            foreach(atom; atoms) {
                char* str = x11b.x11.XGetAtomName(display, atom);
                string name = cast(string)str[0 .. strlen(str)];

                if (name == "UTF8_STRING") {
                    return atom;
                } else if (name == "text/plain;charset=utf-8") {
                    return atom;
                } else if (ret == x11b.None && name == "text/plain") {
                    ret = atom;
                }
            }
        }

        return ret;
    }
}
