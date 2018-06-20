/**
 * Notification tray support for an application.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.features.notificationtray;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.instance;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, theAllocator;

interface Have_NotificationTray {
    shared(Feature_NotificationTray) __getFeatureNotificationTray() shared;
}

interface Feature_NotificationTray {
    @property {
        managed!IWindow getNotificationWindow(IAllocator alloc) shared;
        void setNotificationWindow(managed!IWindow) shared;
        bool haveNotificationWindow() shared;
    }
}

/**
 * Retrieve the applications notification tray window
 * 
 * If the window is not owned by the calling thread, it will return null.
 * 
 * Params:
 *      self    =   The platform instance
 *      alloc   =   The allocator to allocate/deallocate during creation
 * 
 * Returns:
 *      The notification tray window if owned by this thread
 */
managed!IWindow notificationTrayWindow(shared(Management_UserInterface) self, IAllocator alloc=theAllocator) {
    if (self is null)
        return managed!IWindow.init;
    if (shared(Have_NotificationTray) ss = cast(shared(Have_NotificationTray))self) {
        auto fss = ss.__getFeatureNotificationTray();
        if (fss !is null)
            return fss.getNotificationWindow(alloc);
    }
    return managed!IWindow.init;
}

/**
 * Assigns the applications notification tray window
 * 
 * Params:
 *      self    =   The platform instance
 *      to      =   The window to assign as
 */
void notificationTrayWindow(shared(Management_UserInterface) self, managed!IWindow to) {
    if (self is null)
        return;
    if (shared(Have_NotificationTray) ss = cast(shared(Have_NotificationTray))self) {
        auto fss = ss.__getFeatureNotificationTray();
        if (fss !is null)
            fss.setNotificationWindow(to);
    }
}

/**
 * Removes the assigned notification tray window
 * 
 * Params:
 *      self    =   The platform instance
 */
void removeNotificationTrayWindow(shared(Management_UserInterface) self) {
    if (self is null)
        return;
    if (shared(Have_NotificationTray) ss = cast(shared(Have_NotificationTray))self) {
        auto fss = ss.__getFeatureNotificationTray();
        if (fss !is null)
            fss.setNotificationWindow(managed!IWindow.init);
    }
}

/**
 * Does the given platform support the notification tray?
 * 
 * Params:
 *      self    =   The platform instance
 * 
 * Returns:
 *      If the platform supports notifications
 */
@property bool capableOfNotificationTray(shared(Management_UserInterface) self) {
    if (self is null)
        return false;
    else if (shared(Have_NotificationTray) ss = cast(shared(Have_NotificationTray))self)
        return ss.__getFeatureNotificationTray() !is null;
    else
        return false;
}

/**
 * Does the given have a notification window assigned?
 * 
 * Params:
 *      self    =   The platform instance
 * 
 * Returns:
 *      If the platform has a notification window assigned
 */
@property bool haveNotificationWindow(shared(Management_UserInterface) self) {
    if (self is null)
        return false;
    else if (shared(Have_NotificationTray) ss = cast(shared(Have_NotificationTray))self) {
        auto fss = ss.__getFeatureNotificationTray();
        if (fss !is null)
            return fss.haveNotificationWindow();
        else
            return false;
    } else
        return false;
}