module cf.spew.implementation.instance.ui.base;
import cf.spew.implementation.instance.state : uiInstance, windowToIdMapper,
    taskbarTrayWindow, taskbarTrayWindowThread;
import cf.spew.instance : Management_UserInterface;
import cf.spew.ui.features.notificationmessage;
import cf.spew.ui.features.clipboard;
import cf.spew.ui.features.notificationtray;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint,
    IRenderPointCreator;
import stdx.allocator : IAllocator, ISharedAllocator, theAllocator;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import std.experimental.containers.map;
import core.thread : ThreadID;

abstract class UIInstance : Management_UserInterface, Have_NotificationMessage,
    Have_Management_Clipboard, Have_NotificationTray {
        this(shared(ISharedAllocator) allocator) shared {
            this.allocator = allocator;
            windowToIdMapper = SharedMap!(size_t, IWindow)(allocator);

            assert(uiInstance is null);
            uiInstance = this;
        }

        shared(ISharedAllocator) allocator;

        // notifications

        shared(ISharedAllocator) taskbarCustomIconAllocator;
        shared(ImageStorage!RGBA8) taskbarCustomIcon;

        //

        managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared {
            return cast(managed!IRenderPointCreator)createWindow(alloc);
        }

        managed!IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared {
            return cast(managed!IRenderPoint)createAWindow(alloc);
        }

        managed!IWindow createAWindow(IAllocator alloc = theAllocator()) shared {
            import cf.spew.ui.context.features.vram;

            auto creator = createWindow(alloc);
            creator.size = vec2!ushort(cast(short)800, cast(short)600);
            creator.assignVRamContext;
            return creator.createWindow();
        }

        abstract {
            managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared;

            @property {
                managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared;

                managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared;

                managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared;
            }
        }

        // notifications

        shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared {
            return null;
        }

        shared(Feature_NotificationTray) __getFeatureNotificationTray() shared {
            return null;
        }

        // clipboard

        shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
            return null;
        }
    }
