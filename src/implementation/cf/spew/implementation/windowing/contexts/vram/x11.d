module cf.spew.implementation.windowing.contexts.vram.x11;
version (Posix):
import cf.spew.implementation.windowing.contexts.vram.base;
import cf.spew.event_loop.wells.x11;
import devisualization.image.storage.flat;
import devisualization.image.interfaces : ImageStorage, SwappableImage,
    imageObject;
import cf.spew.implementation.windowing.utilities.x11 : x11WindowAttributes;
import x11b = devisualization.bindings.x11;
import stdx.allocator : IAllocator, CAllocatorImpl, make, dispose;
import stdx.allocator.mallocator : AlignedMallocator;
import std.experimental.color : RGB8, RGBA8, BGR8, BGRA8;

final class VRAMContextImpl_X11 : VRAMContextImpl {
    this(x11b.Window whandle, bool assignAlpha, IAllocator alloc) {
        this.whandle = whandle;
        this.alloc = alloc;
        // I'm not sure that it needs to be aligned, but this is talking to system libs so why not
        this.mallocator = alloc.make!(CAllocatorImpl!AlignedMallocator)();

        stage1Alpha = FlatImageStorage!BGRA8(1, 1, alloc);
        stage2 = alloc.make!(SwappableImage!RGB8)(&stage1Alpha);
        stage2Alpha = alloc.make!(SwappableImage!RGBA8)(&stage1Alpha);

        stage3 = imageObject(stage2, alloc);
        stage3Alpha = imageObject(stage2Alpha, alloc);

        graphicGC = x11b.x11.XCreateGC(x11Display(), whandle, 0, null);
        auto screen = x11b.x11.XDefaultScreen(x11Display());
        x11b.x11.XSetBackground(x11Display(), graphicGC,
                x11b.x11.XWhitePixel(x11Display(), screen));
        x11b.x11.XSetForeground(x11Display(), graphicGC,
                x11b.x11.XBlackPixel(x11Display(), screen));
    }

    ~this() {
        alloc.dispose(stage2);
        alloc.dispose(stage2Alpha);
        alloc.dispose(stage3);
        alloc.dispose(stage3Alpha);

        if (x11Image !is null) {
            x11b.x11.XDestroyImage(x11Image);
        }

        x11b.x11.XFreeGC(x11Display(), graphicGC);

        // removes an existing instance without calling the destructor!
        *(&stage1Alpha) = FlatImageStorage!BGRA8.init;
        alloc.dispose(mallocator);
    }

    private {
        IAllocator mallocator;
        IAllocator alloc;

        x11b.Window whandle;
        x11b.XImage* x11Image;
        x11b.GC graphicGC;

        FlatImageStorage!BGRA8 stage1Alpha = void;

        SwappableImage!RGB8* stage2;
        SwappableImage!RGBA8* stage2Alpha;

        ImageStorage!RGB8 stage3;
        ImageStorage!RGBA8 stage3Alpha;
    }

    override {
        @property {
            ImageStorage!RGB8 vramBuffer() {
                return stage3;
            }

            ImageStorage!RGBA8 vramAlphaBuffer() {
                return stage3Alpha;
            }
        }

        void activate() {
            auto attributes = x11WindowAttributes(whandle);
            if (attributes.width != stage1Alpha.width || attributes.height != stage1Alpha.height) {
                if (x11Image !is null)
                    x11b.x11.XDestroyImage(x11Image);

                // removes an existing instance without calling the destructor!
                *(&stage1Alpha) = FlatImageStorage!BGRA8(attributes.width,
                        attributes.height, mallocator);
                x11Image = x11b.x11.XCreateImage(x11Display(), cast(x11b.Visual*)graphicGC,
                        24, x11b.ZPixmap, 0, cast(char*)stage1Alpha.__pixelsRawArray.ptr,
                        attributes.width, attributes.height, 32, 0);
            }
        }

        void deactivate() {
            if (x11Image !is null) {
                x11b.x11.XPutImage(x11Display(), whandle, graphicGC, x11Image,
                        0, 0, 0, 0, cast(uint)stage1Alpha.width, cast(uint)stage1Alpha.height);
            }
        }

        bool readyToBeUsed() {
            return true;
        }
    }
}
