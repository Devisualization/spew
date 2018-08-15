module cf.spew.implementation.consumers.x11;
version (Posix):
import cf.spew.implementation.consumers.base;
import cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.windowing.window.x11;
import cf.spew.implementation.windowing.display.x11;
import cf.spew.implementation.windowing.utilities.x11;
import cf.spew.implementation.instance.ui.x11;
import cf.spew.implementation.instance.state : uiInstance, windowToIdMapper,
    clipboardSendWindowHandleX11, clipboardDataAllocator, clipboardSendData,
    taskbarTrayWindow;
import cf.spew.events.windowing;
import cf.spew.events.defs;
import cf.spew.events.x11;
import cf.spew.event_loop.wells.x11;
import cf.spew.event_loop.known_implementations;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.display.defs : IDisplay;
import cf.spew.ui.rendering : vec2;
import x11b = devisualization.bindings.x11;
import stdx.allocator : dispose;
import std.typecons : Nullable;
import core.stdc.config : c_ulong;

final class EventLoopConsumerImpl_X11 : EventLoopConsumerImpl {
    @property {
        override Nullable!EventSource pairOnlyWithSource() shared {
            return Nullable!EventSource(EventSources.X11);
        }

        bool onMainThread() shared {
            return true;
        }

        bool onAdditionalThreads() shared {
            return true;
        }
    }

    override bool processEvent(ref Event event) shared {
        import core.stdc.string : strlen;
        import core.stdc.stdlib : malloc;

        version (Posix) {
            import cf.spew.implementation.instance.ui.x11;

            if (shared(FreeDesktopNotifications) fdn = cast(shared(
                    FreeDesktopNotifications))uiInstance.__getFeatureNotificationTray()) {
                if (event.wellData1Value == fdn.taskbarSysTrayOwner) {
                    if (event.type == X11_Events_Types.DestroyNotify) {
                        fdn.taskbarSysTrayOwner = x11b.None;
                    }
                }
                fdn.__guardSysTray();

                if (fdn.haveNotificationWindow() && event.wellData1Value ==
                        fdn.taskbarSysTrayWrapper) {

                    switch (event.type) {
                    case Windowing_Events_Types.Window_CursorAction:
                        if ((cast()taskbarTrayWindow).visible) {
                            (cast()taskbarTrayWindow).hide();
                        } else {
                            // attr.x, attr.y

                            auto attr = x11WindowAttributes(cast()fdn.taskbarSysTrayWrapper);
                            int x1 = attr.x;
                            int y1 = attr.y;
                            int w1 = attr.width;
                            int h1 = attr.height;
                            attr = x11WindowAttributes(cast(x11b.Window)(cast()taskbarTrayWindow)
                                    .__handle);
                            int x2 = attr.x;
                            int y2 = attr.y;
                            int w2 = attr.width;
                            int h2 = attr.height;

                            auto allDisplays = uiInstance.displays();
                            foreach (IDisplay d; allDisplays) {
                                DisplayImpl_X11 display = cast(DisplayImpl_X11)d;
                                if (display is null)
                                    continue;

                                if (x2 >= display.x && x2 < display.x + display.width &&
                                        y2 >= display.y && y2 < display.y + display.height) {

                                    int dwl = x1 - display.x;
                                    int dwr = (display.x + display.width) - x1;
                                    int dht = y1 - display.y;
                                    int dhb = (display.y + display.height) - y1;

                                    (cast()taskbarTrayWindow).show();
                                    if (dwl < dwr) {
                                        // |--.-----|

                                        if (dht < dhb) {
                                            // -\ |-.---|
                                            if (dht < dwl)
                                                (cast()taskbarTrayWindow).location = vec2!int(x1,
                                                        y1 + h1);
                                            else
                                                (cast()taskbarTrayWindow).location = vec2!int(x1 + w1,
                                                        y1);
                                        } else {
                                            // -/ |-.---|
                                            if (dhb < dwr)
                                                (cast()taskbarTrayWindow).location = vec2!int(x1,
                                                        y1 - h2);
                                            else
                                                (cast()taskbarTrayWindow).location = vec2!int(x1 + w1,
                                                        (y1 + h1) - h2);
                                        }
                                    } else {
                                        // |-----.--|

                                        if (dht < dhb) {
                                            // -\ |-.---|
                                            if (dht < dwl)
                                                (cast()taskbarTrayWindow).location = vec2!int(x1 + w1,
                                                        y1 + h1);
                                            else
                                                (cast()taskbarTrayWindow).location = vec2!int(x1,
                                                        y1);
                                        } else {
                                            // -/ |-.---|
                                            if (dhb < dwr)
                                                (cast()taskbarTrayWindow).location = vec2!int((x1 + w1) - w2,
                                                        y1 - h2);
                                            else
                                                (cast()taskbarTrayWindow).location = vec2!int(x1 - w2,
                                                        y1 - h1);
                                        }
                                    }
                                }
                            }
                        }
                        return true;

                    case X11_Events_Types.Expose:
                        x11b.Window whandle = cast(x11b.Window)(cast()taskbarTrayWindow).__handle;
                        x11b.Atom net_wm_icon = x11Atoms()._NET_WM_ICON;
                        x11b.Atom cardinal = x11Atoms().CARDINAL;

                        X11WindowProperty prop = x11ReadWindowProperty(x11Display(),
                                whandle, net_wm_icon);
                        scope (exit)
                            if (prop.data !is null)
                                x11b.x11.XFree(prop.data);

                        ubyte[] imageData;
                        uint width, height;

                        if (prop.format == 32 && prop.type == cardinal &&
                                prop.data !is null && prop.numberOfItems > 1) {
                            c_ulong* source = cast(c_ulong*)prop.data;
                            width = cast(uint)source[0];
                            height = cast(uint)source[1];

                            if ((width * height) + 2 == prop.numberOfItems) {
                                imageData = (cast(ubyte*)malloc(4 * width * height))[0 ..
                                    4 * width * height];
                                size_t offset = 2, offset2 = 0;

                                foreach (y; 0 .. height) {
                                    foreach (x; 0 .. width) {
                                        auto p = source[offset++];
                                        imageData[offset2++] = cast(ubyte)p;
                                        imageData[offset2++] = cast(ubyte)(p >> 8);
                                        imageData[offset2++] = cast(ubyte)(p >> 16);
                                        imageData[offset2++] = cast(ubyte)(p >> 24);
                                    }
                                }
                            }
                        }

                        if (imageData.length == 0) {
                            imageData = (cast(ubyte*)malloc(4))[0 .. 1];
                            *cast(uint*)imageData.ptr = 0xCEDEFA00;
                            width = 1;
                            height = 1;
                        }

                        fdn.drawSystray(width, height, cast(uint*)imageData.ptr);
                        return true;

                    default:
                        return false;
                    }
                }
            }
        }

        if (event.wellData1Value == clipboardSendWindowHandleX11) {
            if (event.type == X11_Events_Types.Raw) {
                x11b.XEvent x11Event = event.x11.raw;
                switch (x11Event.type) {
                case x11b.SelectionClear:
                    clipboardDataAllocator.dispose(clipboardSendData);
                    break;
                case x11b.SelectionRequest:
                    x11b.XSelectionRequestEvent* ser = &x11Event.xselectionrequest;

                    if (ser.target != x11Atoms().UTF8_STRING ||
                            ser.property == x11b.None || clipboardSendData.length == 0) {
                        x11b.XSelectionEvent ret;
                        ret.type = x11b.SelectionNotify;
                        ret.requestor = ser.requestor;
                        ret.selection = ser.selection;
                        ret.target = ser.target;
                        ret.property = x11b.None;
                        ret.time = ser.time;

                        x11b.x11.XSendEvent(x11Display(), ser.requestor,
                                x11b.True, x11b.NoEventMask, cast(x11b.XEvent*)&ret);
                    } else {
                        x11b.x11.XChangeProperty(x11Display(), ser.requestor, ser.property,
                                x11Atoms().UTF8_STRING, 8, x11b.PropModeReplace,
                                cast(ubyte*)clipboardSendData.ptr,
                                cast(int)clipboardSendData.length);

                        x11b.XSelectionEvent ret;
                        ret.type = x11b.SelectionNotify;
                        ret.requestor = ser.requestor;
                        ret.selection = ser.selection;
                        ret.target = ser.property;
                        ret.time = ser.time;
                        x11b.x11.XSendEvent(x11Display(), ser.requestor,
                                x11b.True, x11b.NoEventMask, cast(x11b.XEvent*)&ser);
                    }
                    break;
                default:
                    break;
                }
            }
        } else {
            IWindow window = cast()windowToIdMapper[event.wellData1Value];

            if (WindowImpl_X11 w = cast(WindowImpl_X11)window) {
                WindowImpl w2 = cast(WindowImpl)w;

                switch (event.type) {
                case Windowing_Events_Types.Window_KeyUp:
                    tryFunc(w2.onKeyEntryDel, event.windowing.keyInput.key,
                            event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
                    tryFunc(w2.onKeyReleaseDel, event.windowing.keyUp.key,
                            event.windowing.keyUp.special, event.windowing.keyUp.modifiers);
                    return true;
                case Windowing_Events_Types.Window_KeyDown:
                    tryFunc(w2.onKeyPressDel, event.windowing.keyDown.key,
                            event.windowing.keyDown.special, event.windowing.keyDown.modifiers);
                    return true;

                case Windowing_Events_Types.Window_RequestClose:
                    if (tryFunc(w2.onRequestCloseDel, true)) {
                        w.close();
                    }
                    return true;

                case X11_Events_Types.NewSizeLocation:
                    Event temp;
                    if (w.lastX != event.x11.configureNotify.x ||
                            w.lastY != event.x11.configureNotify.y) {
                        w.lastX = event.x11.configureNotify.x;
                        w.lastY = event.x11.configureNotify.y;

                        temp = event;
                        temp.type = Windowing_Events_Types.Window_Moved;
                        temp.windowing.windowMoved.newX = w.lastX;
                        temp.windowing.windowMoved.newY = w.lastY;
                        return super.processEvent(temp);
                    }
                    if (w.lastWidth != event.x11.configureNotify.width ||
                            w.lastHeight != event.x11.configureNotify.height) {
                        w.lastWidth = event.x11.configureNotify.width;
                        w.lastHeight = event.x11.configureNotify.height;

                        temp = event;
                        temp.type = Windowing_Events_Types.Window_Resized;
                        temp.windowing.windowResized.newWidth = w.lastWidth;
                        temp.windowing.windowResized.newHeight = w.lastHeight;
                        return super.processEvent(temp);
                    }
                    return true;
                case Windowing_Events_Types.Window_Hide:
                    w.stateOfVisibleCall = false;
                    tryFunc(w2.onInvisibleDel);
                    return true;

                case X11_Events_Types.Expose:
                    if (!w.stateOfVisibleCall) {
                        tryFunc(w2.onVisibleDel);
                        w.stateOfVisibleCall = true;
                    }

                    return handlePaint(event, w, w2);
                case X11_Events_Types.DestroyNotify:
                    tryFunc(w2.onCloseDel);
                    return true;

                default:
                    if (event.type == X11_Events_Types.Raw) {
                        x11b.XEvent x11Event = event.x11.raw;

                        switch (x11Event.type) {
                        case x11b.ClientMessage:
                            if (x11Event.xclient.message_type == x11Atoms().XdndEnter) {
                                bool moreThanThreeTypes = (x11Event.xclient.data.l[1] & 1) == 1;
                                w.xdndSourceWindow = cast(x11b.Window)x11Event.xclient.data.l[0];
                                w.xdndToBeRequested = x11b.None;

                                if (moreThanThreeTypes) {
                                    X11WindowProperty property = x11ReadWindowProperty(x11Display(),
                                            w.xdndSourceWindow, x11Atoms().XdndTypeList);
                                    if (property.type == x11Atoms().XA_ATOM)
                                        w.xdndToBeRequested = chooseAtomXDND(x11Display(),
                                                (cast(x11b.Atom*)property.data)[0 ..
                                                property.numberOfItems]);
                                    x11b.x11.XFree(property.data);
                                } else {
                                    x11b.Atom[3] listOfAtoms = [
                                        cast(x11b.Atom)x11Event.xclient.data.l[2
                                    ],
                                        x11Event.xclient.data.l[3], x11Event.xclient.data.l[4]];
                                    w.xdndToBeRequested = chooseAtomXDND(x11Display(),
                                            listOfAtoms[]);
                                }

                                tryFunc(w2.onFileDragStartDel);
                            } else if (x11Event.xclient.message_type == x11Atoms().XdndPosition) {
                                x11b.Window _1, _2;
                                int _3, _4, x, y;
                                uint _5;

                                x11b.x11.XQueryPointer(x11Display(), w.whandle,
                                        &_1, &_2, &_3, &_4, &x, &y, &_5);
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

                                x11b.x11.XSendEvent(x11Display(), x11Event.xclient.data.l[0],
                                        x11b.False, x11b.NoEventMask,
                                        cast(x11b.XEvent*)&message);
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

                                    x11b.x11.XSendEvent(x11Display(), x11Event.xclient.data.l[0],
                                            x11b.False, x11b.NoEventMask,
                                            cast(x11b.XEvent*)&message);
                                } else {
                                    x11b.x11.XConvertSelection(x11Display(), x11Atoms().XdndSelection, w.xdndToBeRequested,
                                            x11Atoms().PRIMARY, w.whandle,
                                            x11Event.xclient.data.l[2]);
                                }
                            }
                            break;

                        case x11b.SelectionNotify:
                            if (!w.supportsXDND)
                                break;

                            x11b.Atom target = x11Event.xselection.target;
                            X11WindowProperty property = x11ReadWindowProperty(x11Display(),
                                    w.whandle, x11Atoms().PRIMARY);

                            if (target == x11Atoms().XA_TARGETS) {
                                X11WindowProperty propertyTL = x11ReadWindowProperty(x11Display(),
                                        w.xdndSourceWindow, x11Atoms().XdndTypeList);

                                if (propertyTL.type == x11Atoms().XA_ATOM) {
                                    w.xdndToBeRequested = chooseAtomXDND(x11Display(),
                                            (cast(x11b.Atom*)propertyTL.data)[0 ..
                                            propertyTL.numberOfItems]);
                                    if (w.xdndToBeRequested != x11b.None) {
                                        x11b.x11.XConvertSelection(x11Display(), x11Atoms().XdndSelection, w.xdndToBeRequested, x11Atoms()
                                                .PRIMARY, w.whandle, x11Event.xclient.data.l[2]);
                                    }
                                }
                                x11b.x11.XFree(propertyTL.data);
                            } else if (target == w.xdndToBeRequested) {
                                char* str = cast(char*)property.data;
                                string text = cast(string)str[0 .. strlen(str)];

                                x11b.Window queryPointer1, queryPointer2;
                                int x, y, queryPointer3, queryPointer4;
                                uint queryPointer5;
                                x11b.x11.XQueryPointer(x11Display(), w.whandle, &queryPointer1, &queryPointer2,
                                        &queryPointer3, &queryPointer4, &x,
                                        &y, &queryPointer5);

                                bool canDrop = tryFunc(w2.onFileDraggingDel, false, x, y);
                                if (canDrop) {
                                    size_t start;
                                    foreach (i, c; text) {
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

                                x11b.x11.XSendEvent(x11Display(), w.xdndSourceWindow, x11b.False,
                                        x11b.NoEventMask, cast(x11b.XEvent*)&message);

                                x11b.x11.XDeleteProperty(x11Display(),
                                        w.whandle, x11Atoms().PRIMARY);
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
            foreach (atom; atoms) {
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
