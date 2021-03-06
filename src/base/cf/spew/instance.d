/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.instance;
import devisualization.util.core.memory.managed;

///
abstract class Instance {
    ///
    @property {
        /// The event loop for this application
        shared(Management_EventLoop) eventLoop() shared;
        /// The user interfacing implementation for this application
        shared(Management_UserInterface) userInterface() shared;
        /// Streams implementation aka sockets.
        shared(Management_Streams) streams() shared;
        /// Got a better name for this?
        shared(Management_Miscellaneous) misc() shared;
        ///
        shared(Management_Robot) robot() shared;
        ///
        pragma(inline, true) final shared(Management_UserInterface) ui() shared {
            return userInterface;
        }
    }

    ///
    final nothrow @nogc @trusted {
        ///
        void setAsTheImplementation() shared {
            theInstance_ = this;
        }

        ///
        static {
            /// Default instance implementation, can be null
            shared(Instance) theDefault() {
                return spewDefaultInstance_;
            }

            /// If null, no implementation has been configured
            /// Are you compiling in spew:implementation?
            shared(Instance) current() {
                if (theInstance_ is null)
                    return spewDefaultInstance_;
                else
                    return theInstance_;
            }
        }
    }
}

private __gshared {
    version (Have_spew_implementation) {
        import cf.spew.implementation.instance.main;

        alias spewDefaultInstance_ = DefaultImplementation.Instance;
    } else
        shared(Instance) spewDefaultInstance_;
    shared(Instance) theInstance_;
}

/// Provides a general usage event loop manager overview
interface Management_EventLoop {
    import cf.spew.event_loop.defs : IEventLoopManager;

    /// Does the main thread have an event loop executing?
    bool isRunningOnMainThread() shared;

    /// Does any of the threads have an event loop executing?
    bool isRunning() shared;

    /// Stop the event loop for the current thread
    void stopCurrentThread() shared;

    /// Stop the event loop on all threads
    void stopAllThreads() shared;

    /// Starts the execution of the event loop for the current thread
    void execute() shared;

    /// If you really want to get dirty, here it is!
    @property shared(IEventLoopManager) manager() shared;
}

///
interface Management_UserInterface {
    import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint,
        IRenderPointCreator;
    import stdx.allocator : IAllocator, theAllocator;

    ///
    managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared;

    /// completely up to platform implementation to what the defaults are
    managed!IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared;

    ///
    managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared;

    /// completely up to platform implementation to what the defaults are
    managed!IWindow createAWindow(IAllocator alloc = theAllocator()) shared;

    @property {
        ///
        managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared;

        ///
        managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared;

        ///
        managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared;
    }
}

/// Beware, thread-local!
interface Management_Streams {
    import cf.spew.streams;
    import std.socket : Address;
    import stdx.allocator : IAllocator, theAllocator;

    /// A TCP server
    managed!ISocket_TCPServer tcpServer(Address address,
            ushort listBacklogAmount = 64, IAllocator alloc = theAllocator()) shared;
    /// A TCP client
    managed!ISocket_TCP tcpConnect(Address address, IAllocator alloc = theAllocator()) shared;
    /// A UDP local end point, create destination from this
    managed!ISocket_UDPLocalPoint udpLocalPoint(Address address, IAllocator alloc = theAllocator()) shared;

    ///
    managed!(managed!Address[]) allLocalAddress(IAllocator alloc = theAllocator()) shared;

    ///
    void forceCloseAll() shared;
}

/// Beware, thread-local!
interface Management_Miscellaneous {
    import stdx.allocator : IAllocator, theAllocator;
    import cf.spew.miscellaneous;
    import core.time : Duration;

    /**
     * Creates a timer.
     *
     * Params:
     *     timeout = Timeout till callback is called.
     *     hintSystemWait = If possible an event loop able thread stopper implementation will be used,
     *                      Otherwise a constantly checking one (costly) will be used.
     *     alloc = The allocator
     * Returns:
     *     A timer
     */
    managed!ITimer createTimer(Duration timeout, bool hintSystemWait = true,
            IAllocator alloc = theAllocator()) shared;

    /// Watches a directory recursively (if possible) and notifies of changes.
    managed!IFileSystemWatcher createFileSystemWatcher(string path, IAllocator alloc = theAllocator()) shared;
}

///
interface Management_Robot {
    import cf.spew.events.windowing : KeyModifiers, SpecialKey, CursorEventAction;
    import cf.spew.ui.rendering : vec2;
    import cf.spew.ui.window.defs : IWindow;
    import stdx.allocator : IAllocator, theAllocator;

    @property {
        /// Gets the cursor location
        vec2!int mouseLocation() shared;

        /**
         * Gets the currently keyboard/mouse input focussed window.
         * 
         * Params:
         *     alloc = The allocator to create the returned window with.
         * 
         * Returns:
         *     The window instance, can be null if none currently have focus.
         */
        managed!IWindow focusWindow(IAllocator alloc = theAllocator()) shared;

        /**
         * Focus a window to get keyboard/mouse input.
         * 
         * Params:
         *     window = The window to focus (keyboard/mouse input).
         */
        void focusWindow(managed!IWindow window) shared;
    }

    /**
     * Convenience function to locate a window given its title, can be null.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Params:
     *     title = The precise text that a window has for a title.
     *     alloc = The allocator to create the returned window with.
     * 
     * Returns:
     *     The window instance, can be null if none are found matching.
     * 
     * See_Also:
     *     focusWindow
     */
    managed!IWindow findWindow(string title, IAllocator alloc = theAllocator()) shared;

    /**
     * Sends a key push (up + down) with given modifiers.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Params:
     *    key = The key to send (UTF-32 codepoint).
     *    modifiers = Bitwise or'd list of modifiers.
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *     KeyModifiers, focusWindow
     */
    void sendKey(dchar key, ushort modifiers, managed!IWindow window = managed!IWindow.init) shared;

    /**
     * Sends a key push (up + down) for a specific special key.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Note: This may not actually move the cursor!
     * 
     * Params:
     *    key = The special key to send.
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *     SpecialKey, focusWindow
     */
    void sendKey(SpecialKey key, managed!IWindow window = managed!IWindow.init) shared;

    /**
     * Sends a mouse scroll event at the given x and y coordinates from within the window's content area.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Note: This may not actually move the cursor!
     * 
     * Params:
     *    x = X coordinate, from within the window's content area (if specified).
     *    y = Y coordinate, from within the window's content area (if specified).
     *    amount = The amount to scroll by, postive one amount, negative another direction, use small values.
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *     focusWindow
     */
    void sendScroll(int x, int y, int amount, managed!IWindow window = managed!IWindow.init) shared;

    /**
     * Sends a mouse up/down event at the given x and y coordinates from within the window's content area.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Note: This may not actually move the cursor!
     * 
     * Params:
     *    x = X coordinate, from within the window's content area (if specified).
     *    y = Y coordinate, from within the window's content area (if specified).
     *    isDown = is the button press down or up?
     *    action = Mouse action to send.
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *    CursorEventAction, focusWindow
     */
    void sendMouse(int x, int y, bool isDown, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared;

    /**
     * Sends a mouse move event at the given x and y coordinates from within the window's content area.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Note: This may not actually move the cursor!
     * 
     * Params:
     *    x = X coordinate, from within the window's content area (if specified).
     *    y = Y coordinate, from within the window's content area (if specified).
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *    CursorEventAction, focusWindow
     */
    void sendMouseMove(int x, int y, managed!IWindow window = managed!IWindow.init) shared;

    /**
     * Sends a mouse press (up + down) event at the given x and y coordinates from within the window's content area.
     * 
     * You should manually focus/unfocus the desired window to prevent required thread sleeping.
     * 
     * Note: This may not actually move the cursor!
     * 
     * Params:
     *    x = X coordinate, from within the window's content area (if specified).
     *    y = Y coordinate, from within the window's content area (if specified).
     *    action = Mouse action to send.
     *    window = The window to send to, default the current focussed window.
     * 
     * See_Also:
     *    CursorEventAction, focusWindow
     */
    void sendMouseClick(int x, int y, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared;
}