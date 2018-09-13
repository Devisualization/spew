module cf.spew.implementation.instance.ui.notifications_sdbus;
version(linux):
import cf.spew.implementation.instance.state : taskbarTrayWindow, taskbarTrayWindowThread, taskbarTrayWindowIconDBus;
import cf.spew.event_loop.wells.poll;
import cf.spew.ui.features.notificationmessage;
import cf.spew.ui.features.notificationtray;
import cf.spew.ui : IWindow;
import cf.spew.ui.rendering : vec2;
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

        static sd_bus_vtable vtableProperty(string name, sd_bus_property_get_t getter, string signature) {
            sd_bus_vtable ret;
            ret.type = _SD_BUS_VTABLE_PROPERTY;
            ret.flags = 0;

            ret.x.property.member = name.ptr;
            ret.x.property.signature = signature.ptr;
            ret.x.property.get = getter;
            ret.x.property.set = null;
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

            ret.x.signal.member = name.ptr;
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
            vtableProperty("Title", &spewKDESdBus_Read_Id, "s"),
            vtableProperty("Status", &spewKDESdBus_Read_Status, "s"),
            vtableProperty("WindowId", &spewKDESdBus_Read_WindowId, "i"),
            vtableProperty("IconThemePath", &spewKDESdBus_Read_No, "s"),
            vtableProperty("Menu", &spewKDESdBus_Read_No, "o"),
            vtableProperty("ItemIsMenu", &spewKDESdBus_Read_No, "b"),
            vtableProperty("IconName", &spewKDESdBus_Read_No, "s"),
            vtableProperty("IconPixmap", &spewKDESdBus_Read_IconPixmap, "a(iiay)"),
            vtableProperty("OverlayIconName", &spewKDESdBus_Read_No, "s"),
            vtableProperty("OverlayIconPixmap", &spewKDESdBus_Read_No, "a(iiay)"),
            vtableProperty("AttentionIconName", &spewKDESdBus_Read_No, "s"),
            vtableProperty("AttentioniconPixmap", &spewKDESdBus_Read_No, "a(iiay)"),
            vtableProperty("AttentionMovieName", &spewKDESdBus_Read_No, "s"),
            vtableProperty("ToolTip", &spewKDESdBus_Read_ToolTip, "(sa(iiay)ss)"),

            vtableMethod("ContextMenu", &spewKDESdBus_NoMethod, "ii"),
            vtableMethod("Activate", &spewKDESdBus_Activate, "ii"),
            vtableMethod("SecondaryActivate", &spewKDESdBus_NoMethod, "ii"),
            vtableMethod("Scroll", &spewKDESdBus_NoMethod, "is"),

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

    void prepareNewIcon(scope ImageStorage!RGBA8 icon) shared {
        import core.atomic;
        import core.stdc.stdlib : malloc, free;

        // ARGB32: a(iiay)
        // uint [( int, int, uint, [ ubyte ] )]

        shared(ubyte)* newWindowIcon;
        if (icon is null || icon.width * icon.height * 4 >= 63 * 1024 * 1024) {
            // 63mb
        } else {
            newWindowIcon = cast(shared(ubyte)*)malloc((4 * 4) + (4 * icon.width * icon.height));
            uint[] buf = (cast(uint*)newWindowIcon)[0 .. 4 + (icon.width * icon.height)];

            buf[0] = 1;
            buf[1] = cast(uint)icon.width;
            buf[2] = cast(uint)icon.height;
            buf[3] = cast(uint)(icon.width * icon.height * 4);

            buf = buf[4 .. $];

            size_t count;
            foreach(y; 0 .. icon.height) {
                foreach(x; 0 .. icon.width) {
                    uint temp;
                    auto color = icon[x, y];

                    import std.stdio;


                    temp |= cast(uint)color.a.value;
                    temp |= (cast(uint)color.r.value) << 8;
                    temp |= (cast(uint)color.r.value) << 16;
                    temp |= (cast(uint)color.r.value) << 24;
writeln(x, "x", y,": ", temp);
                    buf[count++] = temp;
                }
            }
        }
        assert(0);

        /+shared(ubyte)* currentWindowIcon = atomicLoad(taskbarTrayWindowIconDBus);

        while(!cas(&taskbarTrayWindowIconDBus, currentWindowIcon, newWindowIcon)) {
            currentWindowIcon = atomicLoad(taskbarTrayWindowIconDBus);
        }

        if (currentWindowIcon !is null)
            free(cast(void*)currentWindowIcon);

        systemd.sd_bus_emit_signal(cast(sd_bus*)bus, "/StatusNotifierItem".ptr, "org.kde.StatusNotifierItem".ptr, "NewIcon".ptr, "".ptr);+/
    }

    private {
        const sd_bus_vtable[2 + 16 + 4 + 6] sysTrayVtable;
        char["org.kde.StatusNotifierItem-".length + 8 + 3] sysTrayId;
        sd_bus_slot* sysTraySlot;

        void __guardSysTray() shared {
            import cf.spew.ui.window.features.icon : icon;

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

                systemd.sd_bus_emit_signal(cast(sd_bus*)bus, "/StatusNotifierItem".ptr, "org.kde.StatusNotifierItem".ptr, "NewTitle".ptr, "".ptr);
                systemd.sd_bus_emit_signal(cast(sd_bus*)bus, "/StatusNotifierItem".ptr, "org.kde.StatusNotifierItem".ptr, "NewStatus".ptr, "s".ptr, "Active".ptr);
                systemd.sd_bus_emit_signal(cast(sd_bus*)bus, "/StatusNotifierItem".ptr, "org.kde.StatusNotifierItem".ptr, "NewToolTip".ptr, "".ptr);

                prepareNewIcon((cast()taskbarTrayWindow).icon);

                systemd.sd_bus_call_method_async(cast(sd_bus*)bus, null, "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                    "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem",
                    &spewSDBusRegisterWatcherCallback, null,
                    "s" /+ types +/,
                    cast(char*)sysTrayId.ptr);
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

    extern(C) int spewSDBusRegisterWatcherCallback(sd_bus_message* message, void*, sd_bus_error*) {
        systemd.sd_bus_message_unref(message);
        return 0;
    }

    // from rt.dmain2
    struct CArgs {
        int argc;
        char** argv;
    }
    extern extern(C) CArgs rt_cArgs() @nogc;

    extern(C) {
        int spewKDESdBus_Activate(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            int x, y;
            int r = systemd.sd_bus_message_read(msg, "ii", &x, &y);
            if (r < 0)
                return 0;

            (cast()taskbarTrayWindow).show();
            (cast()taskbarTrayWindow).location = vec2!int(x, y);

            return systemd.sd_bus_reply_method_return(msg, null);
        }
        int spewKDESdBus_NoMethod(sd_bus_message* msg, void* ctx, sd_bus_error* error) {
            return 0;
        }

        int spewKDESdBus_Read_Category(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            systemd.sd_bus_message_append(reply, "s", "ApplicationStatus".ptr);
            return 1;
        }

        int spewKDESdBus_Read_WindowId(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            if (cast()taskbarTrayWindow !is managed!IWindow.init) {
                import cf.spew.implementation.windowing.window.x11 : WindowImpl_X11;

                managed!WindowImpl_X11 wx11 = cast(managed!WindowImpl_X11)(cast()taskbarTrayWindow);

                if (!wx11.isNull) {
                    systemd.sd_bus_message_append(reply, "i", cast(int)cast(size_t)wx11.__handle());
                    return 0;
                }
            }

            systemd.sd_bus_reply_method_return(reply, "".ptr);
            return 0;
        }

        int spewKDESdBus_Read_Id(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            if (rt_cArgs().argc > 0) {
                size_t lastSlash, i;
                char* temp = rt_cArgs().argv[0];

                while(temp[i]) {
                    if (temp[i] == '\\' || temp[i] == '/')
                        lastSlash = i+1;
                    i++;
                }

                systemd.sd_bus_message_append(reply, "s", rt_cArgs().argv[0] + lastSlash);
            } else
                systemd.sd_bus_reply_method_return(reply, "".ptr);

            return 1;
        }

        int spewKDESdBus_Read_Status(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            if (cast()taskbarTrayWindow !is managed!IWindow.init)
                systemd.sd_bus_message_append(reply, "s", "Active".ptr);
            else
                systemd.sd_bus_reply_method_return(reply, "".ptr);

            return 1;
        }

        int spewKDESdBus_Read_IconPixmap(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            import core.atomic : atomicLoad;

            ubyte* temp = cast(ubyte*)atomicLoad(taskbarTrayWindowIconDBus);
            if (temp !is null) {
                uint[4] args = (cast(uint*)temp)[0 .. 4];

                auto r = systemd.sd_bus_message_open_container(reply, 'a', "(iiay)".ptr);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_open_container(reply, 'r', "iiay".ptr);
                if (r < 0) return 0;

                r = systemd.sd_bus_message_append(reply, "ii".ptr, cast(int)args[1], cast(int)args[2]);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_append_array(reply, 'y', temp + (4*4), args[3]);
                if (r < 0) return 0;

                r = systemd.sd_bus_message_close_container(reply);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_close_container(reply);
                if (r < 0) return 0;
            } else
                systemd.sd_bus_reply_method_return(reply, "".ptr);

            return 1;
        }

        int spewKDESdBus_Read_ToolTip(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            // (sa(iiay)ss)

            if (rt_cArgs().argc > 0) {
                size_t lastSlash, i;
                char* temp = rt_cArgs().argv[0];

                while(temp[i]) {
                    if (temp[i] == '\\' || temp[i] == '/')
                        lastSlash = i+1;
                    i++;
                }

                auto r = systemd.sd_bus_message_open_container(reply, 'r', "sa(iiay)ss".ptr);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_append(reply, "s", rt_cArgs().argv[0] + lastSlash);
                if (r < 0) return 0;

                r = systemd.sd_bus_message_open_container(reply, 'a', "(iiay)".ptr);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_close_container(reply);
                if (r < 0) return 0;

                r = systemd.sd_bus_message_append(reply, "ss", "".ptr, "".ptr);
                if (r < 0) return 0;
                r = systemd.sd_bus_message_close_container(reply);
                if (r < 0) return 0;
            } else
                systemd.sd_bus_reply_method_return(reply, "".ptr);

            return 1;
        }

        int spewKDESdBus_Read_No(sd_bus* bus, const char* path, const char* interface_, const char* property, sd_bus_message* reply, void* userdata, sd_bus_error* ret_error) {
            return systemd.sd_bus_reply_method_return(reply, null);
        }
    }
}
