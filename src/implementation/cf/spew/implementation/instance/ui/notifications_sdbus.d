module cf.spew.implementation.instance.ui.notifications_sdbus;
version(linux):
import cf.spew.implementation.instance.state : taskbarTrayWindow, taskbarTrayWindowThread;
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
import core.thread : Thread, ThreadID;

final class SDBus_KDENotifications : Feature_NotificationMessage, Feature_NotificationTray {
    shared(ISharedAllocator) alloc;
    sd_bus* bus;
    bool enableTray;

    this(shared(ISharedAllocator) alloc) shared {
        import std.process : thisProcessID;
        import std.format : sformat;
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

        static sd_bus_vtable vtableProperty(string name, sd_bus_message_handler_t handler, string signature) {
            sd_bus_vtable ret;
            ret.type = _SD_BUS_VTABLE_PROPERTY;
            ret.flags = 0;

            ret.x.property.member = name.ptr;
            ret.x.property.signature = signature.ptr;
            ret.x.property.get = handler;
            ret.x.property.offset = 0;

            return ret;
        }

        static sd_bus_vtable vtableMethod(string name, sd_bus_message_handler_t handler, string signature=null, string result=null) {
            sd_bus_vtable ret;
            ret.type = _SD_BUS_VTABLE_METHOD;
            ret.flags = 0;

            ret.x.method.member = name.ptr;
            ret.x.method.signature = signature.ptr;
            ret.x.method.result = result.ptr;
            ret.x.method.handler = handler;
            ret.x.method.offset = 0;

            return ret;
        }

        static sd_bus_vtable vtableSignal(string name, string signature=null) {
            sd_bus_vtable ret;
            ret.type = _SD_BUS_VTABLE_SIGNAL;
            ret.flags = 0;

            ret.x.signal.name = name.ptr;
            ret.x.signal.signature = signature.ptr;

            return ret;
        }

        sysTrayVtable = [
            () {
                sd_bus_vtable ret;
                ret.type = _SD_BUS_VTABLE_START;
                ret.flags = 0;
                ret.x.start.element_size = sd_bus_vtable.sizeof;
                return ret;
            }(),

            vtableProperty("Category", &spewKDESdBus_Read_Category, "s"),
            vtableProperty("Id", &spewKDESdBus_Read_Id, "s"),
            vtableProperty("Title", null, "s"),
            vtableProperty("Status", &spewKDESdBus_Read_Status, "s"),
            vtableProperty("WindowId", &spewKDESdBus_Read_WindowId, "i"),
            vtableProperty("IconThemePath", null, "s"),
            vtableProperty("Menu", null, "o"),
            vtableProperty("ItemIsMenu", null, "b"),
            vtableProperty("IconName", null, "s"),
            vtableProperty("IconPixmap", &spewKDESdBus_Read_IconPixmap, "a(iiay)"),
            vtableProperty("OverlayIconName", null, "s"),
            vtableProperty("OverlayIconPixmap", null, "a(iiay)"),
            vtableProperty("AttentionIconName", null, "s"),
            vtableProperty("AttentioniconPixmap", null, "a(iiay)"),
            vtableProperty("AttentionMovieName", null, "s"),
            vtableProperty("ToolTip", null, "sa(iiay)ss"),

            vtableMethod("ContextMenu", null, "ii"),
            vtableMethod("Activate", &spewKDESdBus_Activate, "ii"),
            vtableMethod("SecondaryActivate", null, "ii"),
            vtableMethod("Scroll", null, "is"),

            vtableSignal("NewTitle"),
            vtableSignal("NewIcon"),
            vtableSignal("NewAttentionIcon"),
            vtableSignal("NewOverlayIcon"),
            vtableSignal("NewToolTip"),
            vtableSignal("NewStatus", "s"),

            sd_bus_vtable(_SD_BUS_VTABLE_END)
        ];

        // setup the name for our notification item for easy access

        enum SysTNI = "org.kde.StatusNotifierItem-";
        sysTrayId[0 .. SysTNI.length] = SysTNI;

        char[] tempPID = (cast(char[])(sysTrayId[SysTNI.length .. SysTNI.length + 8])).sformat!"%d"(thisProcessID());
        sysTrayId[SysTNI.length + tempPID.length .. SysTNI.length + tempPID.length + 3] = "-1\0";
    }

    ~this() {
        if (bus is null) return;
        PollEventLoopSource.instance.unregisterFD(systemd.sd_bus_get_fd(cast(sd_bus*)bus));
        (cast(shared)this).sysTrayRelease();

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

        void setNotificationWindow(managed!IWindow window) shared {
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
        const sd_bus_vtable[10 + 4 + 6] sysTrayVtable;
        char["org.freedesktop.StatusNotifierItem-".length + 8 + 3] sysTrayId;
        sd_bus_slot* sysTraySlot;

        void __guardSysTray() shared {
            sysTrayRelease();

            if (!(cast()taskbarTrayWindow).isNull) {
                auto r = systemd.sd_bus_request_name(cast(sd_bus*)bus, cast(char*)sysTrayId.ptr, 0);
                if (r < 0) {
                    taskbarTrayWindow = managed!IWindow.init;
                    return;
                }

                r = systemd.sd_bus_add_object_vtable(cast(sd_bus*)bus, cast(sd_bus_slot**)&sysTraySlot,
                    "/StatusNotifierItem".ptr,
                    "org.kde.StatusNotifierItem".ptr,
                    cast(sd_bus_vtable*)sysTrayVtable.ptr,
                    null);

                if (r < 0) {
                    taskbarTrayWindow = managed!IWindow.init;
                    systemd.sd_bus_release_name(cast(sd_bus*)bus, cast(char*)sysTrayId.ptr);
                    return;
                }

                // TODO: can we support the signals NewTitle and NewIcon?
            }
        }

        void sysTrayRelease() shared {
            if (sysTraySlot !is null) {
                systemd.sd_bus_slot_unref(cast(sd_bus_slot*)sysTraySlot);
                sysTraySlot = null;
                systemd.sd_bus_release_name(cast(sd_bus*)bus, cast(char*)sysTrayId.ptr);
            }
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
        systemd.sd_bus_error_free(&error);
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
        systemd.sd_bus_error_free(&error);
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

    extern(C) {
        int spewKDESdBus_Activate(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // x:i, y:i
            return 1;
        }

        int spewKDESdBus_Read_Category(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // TODO: return "ApplicationStatus" type s
            return 1;
        }
        int spewKDESdBus_Read_WindowId(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // TODO: if x11 or wayland return, else 0 type i
            return 1;
        }
        int spewKDESdBus_Read_Id(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // TODO: return application's binary name type s
            return 1;
        }
        int spewKDESdBus_Read_Status(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // TODO: if we have a window, return "Active" else "Passive" type s
            return 1;
        }
        int spewKDESdBus_Read_IconPixmap(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            // TODO: if we have a window with icon, return icon of the window type a(iiay)
            return 1;
        }
    }
}
