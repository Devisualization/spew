module cf.spew.implementation.instance.state;
import cf.spew.implementation.instance.ui.base : UIInstance;
import cf.spew.implementation.streams.base : StreamPoint;
import cf.spew.miscellaneous.timer;
import cf.spew.ui.window.defs : IWindow;
import devisualization.util.core.memory.managed;
import std.experimental.containers.map;
import stdx.allocator : ISharedAllocator, dispose;
import core.thread : Thread, ThreadID;

package(cf.spew.implementation):

__gshared {
    shared(UIInstance) uiInstance;
    shared(ISharedAllocator) clipboardDataAllocator;
    shared(SharedMap!(size_t, ITimer)) timerToIdMapper;
    shared(SharedMap!(size_t, IWindow)) windowToIdMapper;

    managed!IWindow taskbarTrayWindow;
    ThreadID taskbarTrayWindowThread;
    shared(ubyte*) taskbarTrayWindowIconDBus;
}

// \/ TLS

StreamPoint streamPointsLL;

version (Posix) {
    import x11b = devisualization.bindings.x11;

    x11b.Window clipboardReceiveWindowHandleX11, clipboardSendWindowHandleX11;
    char[] clipboardSendData;

    static ~this() {
        if (clipboardDataAllocator !is null && clipboardSendData.length > 0) {
            clipboardDataAllocator.dispose(clipboardSendData);
        }
    }
}

// /\ TLS

shared static ~this() {
    if (uiInstance is null)
        return;

    if (!taskbarTrayWindow.isNull && Thread.getThis().id == taskbarTrayWindowThread) {

        if (uiInstance.__getFeatureNotificationTray() !is null)
            uiInstance.__getFeatureNotificationTray().setNotificationWindow(managed!IWindow.init);
        taskbarTrayWindow = managed!IWindow.init;
    }
}
