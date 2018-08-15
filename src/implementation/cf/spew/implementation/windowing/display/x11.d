module cf.spew.implementation.windowing.display.x11;
version (Posix):
import cf.spew.implementation.windowing.display.base;
import cf.spew.implementation.windowing.utilities.x11 : GetWindows_X11;
import cf.spew.ui.display.defs;
import cf.spew.ui.display.features.screenshot;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.event_loop.wells.x11;
import devisualization.util.core.memory.managed;
import devisualization.bindings.x11;
import devisualization.image : ImageStorage, ImageStorageHorizontal;
import std.experimental.color : RGB8;
import stdx.allocator : IAllocator, make, makeArray, dispose;
import core.stdc.config : c_ulong;

final class DisplayImpl_X11 : DisplayImpl, Feature_Display_ScreenShot, Have_Display_ScreenShot {
    Screen* screen;
    RROutput rrOutput;

    int x, y;
    int width, height;

    this(DisplayImpl_X11 other) {
        this.alloc = other.alloc;
        this.screen = other.screen;
        this.rrOutput = other.rrOutput;
        this.x = other.x;
        this.y = other.y;
        this.width = other.width;
        this.height = other.height;
        this.name_ = other.name_;
        this.primaryDisplay_ = other.primaryDisplay_;
        this.size_ = other.size_;
        this.refreshRate_ = other.refreshRate_;
    }

    this(Screen* screen, XRRMonitorInfo* monitor, IAllocator alloc) {
        import core.stdc.string : strlen;

        this.screen = screen;
        this.alloc = alloc;

        auto root = x11.XRootWindowOfScreen(screen);
        XRRScreenConfiguration* screenConfig = x11.XRRGetScreenInfo(x11Display(), root);
        refreshRate_ = x11.XRRConfigCurrentRate(screenConfig);

        // we need this to dectect windows.
        x = monitor.x;
        y = monitor.y;
        width = monitor.width;
        height = monitor.height;

        size_.x = cast(ushort)monitor.width;
        size_.y = cast(ushort)monitor.height;

        char* name = x11.XGetAtomName(x11Display(), monitor.name);
        char[] dupedName = alloc.makeArray!char(strlen(name));
        dupedName[] = name[0 .. dupedName.length];
        name_ = managed!string(cast(string)dupedName, managers(ReferenceCountedManager()), alloc);
        x11.XFree(name);

        primaryDisplay_ = monitor.primary == 1;

        if (monitor.noutput >= 1)
            rrOutput = monitor.outputs[0];
    }

    @property {
        uint luminosity() {
            Atom XA_INTEGER = x11Atoms().INTEGER;
            Atom backlightAtom = x11Atoms().Backlight;
            Atom backlightAtomOld = x11Atoms().BACKLIGHT;

            if (backlightAtom <= 0) {
                backlightAtom = backlightAtomOld;
            }

            if (backlightAtom > 0 && rrOutput > 0) {
                auto root = x11.XRootWindowOfScreen(screen);

                Atom actualType;
                int actualFormat;
                c_ulong nitems, bytesAfter;
                ubyte* prop;

                x11.XRRGetOutputProperty(x11Display(), rrOutput, backlightAtom, 0, 4, False,
                        False, None, &actualType, &actualFormat, &nitems, &bytesAfter, &prop);

                if (actualType != XA_INTEGER || nitems != 1 || actualFormat != 32) {
                    if (prop !is null)
                        x11.XFree(prop);
                    return 10;
                } else {
                    import core.stdc.config : c_long;

                    c_long ret = *cast(c_long*)prop;
                    x11.XFree(prop);
                    return cast(uint)ret;
                }
            }

            return 10;
        }

        managed!(IWindow[]) windows() {
            GetWindows_X11 ctx;
            ctx.display = this;
            ctx.alloc = alloc;
            ctx.call;

            return managed!(IWindow[])(ctx.windows, managers(), alloc);
        }

        size_t __handle() {
            return cast(size_t)screen;
        }
    }

    Feature_Display_ScreenShot __getFeatureScreenShot() {
        return this;
    }

    ImageStorage!RGB8 screenshot(IAllocator alloc = null) {
        import devisualization.image : ImageStorage;
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObject;
        import std.experimental.color : RGB8, RGBA8;

        if (alloc is null)
            alloc = this.alloc;

        Window rootWindow = x11.XDefaultRootWindow(x11Display());
        XImage* complete = x11.XGetImage(x11Display(),
                cast(Drawable)rootWindow, x, y, width, height, AllPlanes, ZPixmap);
        auto storage = imageObject!(ImageStorageHorizontal!RGB8)(size_.x, size_.y, alloc);

        foreach (y; 0 .. height) {
            foreach (x; 0 .. width) {
                auto pix = x11.XGetPixel(complete, x, y);
                storage[x, y] = RGB8(cast(ubyte)((pix & complete.red_mask) >> 16),
                        cast(ubyte)((pix & complete.green_mask) >> 8),
                        cast(ubyte)(pix & complete.blue_mask));
            }
        }

        x11.XFree(complete);
        return storage;
    }

    IDisplay dup(IAllocator alloc) {
        return alloc.make!DisplayImpl_X11(this);
    }
}
