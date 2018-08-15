module cf.spew.implementation.consumers.base;
import cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.instance.main;
import cf.spew.implementation.instance.state : windowToIdMapper;
import cf.spew.event_loop.defs;
import cf.spew.events.windowing;
import cf.spew.events.defs;
import cf.spew.ui.window.defs : IWindow;
import std.typecons : Nullable;
import std.traits : ReturnType;

void tryFunc(T, U...)(T func, U args) if (is(ReturnType!T == void)) {
    if (func !is null) {
        try {
            func(args);
        } catch (Exception e) {
        }
    }
}

J tryFunc(T, J = ReturnType!T, U...)(T func, J default_, U args)
        if (!is(ReturnType!T == void)) {
    if (func !is null) {
        try {
            return func(args);
        } catch (Exception e) {
        }
    }

    return default_;
}

abstract class EventLoopConsumerImpl : EventLoopConsumer {
    bool processEvent(ref Event event) shared {
        // umm shouldn't we check that you know this is a windowing event?
        IWindow window = cast()windowToIdMapper[event.wellData1Value];

        if (window is null) {
        } else if (WindowImpl w = cast(WindowImpl)window) {
            switch (event.type) {
            case Windowing_Events_Types.Window_Moved:
                tryFunc(w.onMoveDel,
                        event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
                return true;
            case Windowing_Events_Types.Window_Resized:
                tryFunc(w.onSizeChangeDel,
                        event.windowing.windowResized.newWidth,
                        event.windowing.windowResized.newHeight);
                return true;
            case Windowing_Events_Types.Window_CursorScroll:
                tryFunc(w.onScrollDel, event.windowing.scroll.amount);
                return true;
            case Windowing_Events_Types.Window_CursorMoved:
                tryFunc(w.onCursorMoveDel,
                        event.windowing.cursorMoved.newX, event.windowing.cursorMoved.newY);
                return true;
            case Windowing_Events_Types.Window_CursorAction:
                tryFunc(w.onCursorActionDel, event.windowing.cursorAction.action);
                return true;
            case Windowing_Events_Types.Window_CursorActionEnd:
                tryFunc(w.onCursorActionEndDel, event.windowing.cursorAction.action);
                return true;

            case Windowing_Events_Types.Window_KeyInput:
            case Windowing_Events_Types.Window_KeyUp:
                tryFunc(w.onKeyEntryDel,
                        event.windowing.keyInput.key, event.windowing.keyInput.special,
                        event.windowing.keyInput.modifiers);
                return true;

            case Windowing_Events_Types.Window_Show:
                tryFunc(w.onVisibleDel);
                return true;
            case Windowing_Events_Types.Window_Hide:
                tryFunc(w.onInvisibleDel);
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
        Nullable!EventSource pairOnlyWithSource() shared {
            return Nullable!EventSource();
        }

        EventType pairOnlyWithEvents() shared {
            return EventType.all;
        }

        byte priority() shared {
            return byte.max / 2;
        }

        string description() shared {
            return "Default implementation consumer for Windowing.";
        }
    }
}
