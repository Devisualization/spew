/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.events.x11;
import cf.spew.events.defs;
import devisualization.bindings.x11 : XEvent;

///
enum X11_Events_Types {
    ///
    Prefix = EventType.from("|x"),
    ///
    Unknown = EventType.from("|xunknwn"),
    ///
    Expose = EventType.from("|xexpose"),
    /// ConfigureNotify
    NewSizeLocation = EventType.from("|xnewsl"),
    ///
    DestroyNotify = EventType.from("|xdstrw"),
    ///
    Raw = EventType.from("|xraw")
}

///
struct X11_Events {
    ///
    X11_Event_ConfigureNotify configureNotify;
    ///
    XEvent raw;
}

///
struct X11_Event_ConfigureNotify {
    ///
    int x, y;
    ///
    int width, height;
}
