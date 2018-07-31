/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.known_implementations;
import cf.spew.events.defs : EventSource;

/**
 * 
 */
enum EventSources {
    ///
    Prefix = EventSource.from("s_"),

    ///
    WinAPI = EventSource.from("s_winapi"),
    ///
    X11 = EventSource.from("s_x11"),
    ///
    Cocoa = EventSource.from("s_cocoa"),

    ///
    LibUV = EventSource.from("s_libuv"),
    ///
    Glib = EventSource.from("s_glib"),

    /// Posix
    Poll = EventSource.from("s_poll"),

    /// Linux
    Epoll = EventSource.from("s_epoll"),
}
