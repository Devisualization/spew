module cf.spew.implementation.instance.ui.notifications_sdbus;
version(linux):
import cf.spew.implementation.instance.ui.state : taskbarTrayWindow, taskbarTrayWindowThread;
import cf.spew.event_loop.wells.poll;
import cf.spew.ui.features.notificationmessage;
import cf.spew.ui.features.notificationtray;
import cf.spew.ui : IWindow;
import devisualization.util.core.memory.managed;
import devisualization.image.interfaces : ImageStorage;
import devisualization.bindings.systemd;
import stdx.allocator : IAllocator, ISharedAllocator, make, dispose/+,
    processAllocator, theAllocator+/, makeArray;
import std.experimental.color : RGBA8;
import std.utf : byChar, codeLength;

final class SDBus_KDENotifications : Feature_NotificationMessage, Feature_NotificationTray {
    shared(ISharedAllocator) alloc;
    sd_bus* bus;

    this(shared(ISharedAllocator) alloc) shared {
        this.alloc = alloc;

        assert(systemd.sd_bus_open_user(cast(sd_bus**)&bus) >= 0, "Could not create the sd-bus session to user bus");
        assert(bus !is null, "Could not create the sd-bus session to user bus");

        PollEventLoopSource.instance.registerFD(systemd.sd_bus_get_fd(cast(sd_bus*)bus), (int) {
            size_t counter;
            while(systemd.sd_bus_process(cast(sd_bus*)bus, null) > 0 && counter < 4) {
                // hi?
                counter++;
            }
        });
    }

    ~this() {
        if (bus is null) return;
        PollEventLoopSource.instance.unregisterFD(systemd.sd_bus_get_fd(cast(sd_bus*)bus));

        systemd.sd_bus_flush(bus);
        systemd.sd_bus_unref(bus);
    }

    @property {
        managed!IWindow getNotificationWindow(IAllocator alloc) shared {
            if (cast()taskbarTrayWindow is managed!IWindow.init ||
                    taskbarTrayWindowThread != Thread.getThis().id)
                return managed!IWindow.init;
            else
                return cast()taskbarTrayWindow;
        }

        void setNotificationWindow(managed!IWindow) shared {
            cast()taskbarTrayWindow = window;
            __guardSysTray();
        }

        bool haveNotificationWindow() shared {
            return cast()taskbarTrayWindow !is managed!IWindow.init;
        }
    }

    void notify(shared(ImageStorage!RGBA8) icon, dstring title, dstring text, shared(ISharedAllocator) alloc) shared {
        char[] bufferTitle = alloc.makeArray!char(codeLength!char(title) + 1);
        char[] bufferText = alloc.makeArray!char(codeLength!char(text) + 1);
        bufferTitle[$-1] = 0;
        bufferText[$-1] = 0;

        size_t i;
        foreach(c; title.byChar) {
            bufferTitle[i] = c;
            i++;
        }

        i = 0;
        foreach(c; text.byChar) {
            bufferText[i] = c;
            i++;
        }

        NotifyBuffers* userdata = alloc.make!NotifyBuffers;
        userdata.title = bufferTitle;
        userdata.text = bufferText;
        userdata.alloc = alloc;

        // TODO: hint image-data
        //  iiibiiay width, height, rowstride, hasAlpha, bps, channels, uint*

        systemd.sd_bus_call_method_async(cast(sd_bus*)bus, null, "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "Notify",
            &spewSDBusNotifyCallback, cast(void*)userdata,
            "susssasa{sv}i" /+ types +/,
            "SPEW library notifications".ptr /+ our applications name, optional, blank +/,
            0 /+ replace id +/,
            null /+ Not supported: application icon +/,
            bufferTitle.ptr /+ title +/,
            bufferText.ptr /+ body +/,
            null /+ actions ARRAY +/,
            null /+ hints DICT +/,
            -1 /+ expire_timeout, let the server decide when to close +/);
    }

    void clearNotifications() shared {
        // if we supported this, we'd have to store id's, no thank you
    }

    private {
        void __guardSysTray() {

        }
    }
}

bool checkForSystemDBus() {
    if (systemdLoader is SystemDLoader.init)
        systemdLoader = SystemDLoader(null);
    return systemd.sd_bus_default_user !is null;
}

bool checkForSDBusKDETray() {
    if (!checkForSystemDBus)
        return false;

    sd_bus* bus;
    if (systemd.sd_bus_default_user(&bus) < 0)
        return false;

    sd_bus_error error;
    sd_bus_message* message;

    scope (exit) {
        if (message !is null)
            systemd.sd_bus_message_unref(message);
        systemd.sd_bus_unref(bus);
    }

    // lets find out if the interface exists
    // we're using the "kde" namespace, because that is what is implemented /sigh/
    // it should be freedesktop :/
    int r = systemd.sd_bus_call_method(bus, "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
            "org.freedesktop.DBus.Introspectable", "Introspect", &error, &message, "");

    // much cheaper to see if there is a body than to actually get it ;)
    return r >= 0 && systemd.sd_bus_message_is_empty(message) == 0;
}

bool checkForSDBusFreeDesktopBubble() {
    if (!checkForSystemDBus)
        return false;

    sd_bus* bus;
    if (systemd.sd_bus_default_user(&bus) < 0)
        return false;

    sd_bus_error error;
    sd_bus_message* message;

    scope (exit) {
        if (message !is null)
            systemd.sd_bus_message_unref(message);
        systemd.sd_bus_unref(bus);
    }

    // lets find out if the interface exists
    int r = systemd.sd_bus_call_method(bus, "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.DBus.Introspectable", "Introspect", &error, &message, "");

    // much cheaper to see if there is a body than to actually get it ;)
    return r >= 0 && systemd.sd_bus_message_is_empty(message) == 0;
}

private {
    struct NotifyBuffers {
        char[] title, text;
        shared(ISharedAllocator) alloc;
    }

    extern(C) int spewSDBusNotifyCallback(sd_bus_message* message, void* userdata, sd_bus_error*) {
        NotifyBuffers* buffers = cast(NotifyBuffers*)userdata;
        buffers.alloc.dispose(buffers.title);
        buffers.alloc.dispose(buffers.text);
        buffers.alloc.dispose(buffers);
        systemd.sd_bus_message_unref(message);
        return 0;
    }
}
