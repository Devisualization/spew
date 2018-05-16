/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.contexts.vram;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features.vram;
import devisualization.image : ImageStorage;
import devisualization.image.interfaces : SwappableImage, imageObject;
import devisualization.image.storage.flat;
import std.experimental.color : RGB8, RGBA8, BGR8, BGRA8;
import stdx.allocator : IAllocator, make, dispose;
import x11b = devisualization.bindings.x11;

class VRAMContextImpl : IContext, Have_VRam, Feature_VRam {
	Feature_VRam __getFeatureVRam() {
		return this;
	}

	@property {
		ImageStorage!RGB8 vramBuffer() { assert(0); }
		ImageStorage!RGBA8 vramAlphaBuffer() { assert(0); }
	}

	void activate() { assert(0); }
	void deactivate() { assert(0); }
	bool readyToBeUsed() { assert(0); }
}

version(Windows) {
	final class VRAMContextImpl_WinAPI : VRAMContextImpl {
		import core.sys.windows.windows : HWND, HDC, GetDC, CreateCompatibleDC, IsWindowVisible,
			RECT, GetClientRect, HBITMAP, CreateBitmap, HGDIOBJ, SelectObject, GetObjectA, StretchBlt,
			DeleteObject, InvalidateRgn, SRCCOPY;

		this(HWND hwnd, bool assignAlpha, IAllocator alloc) {
			this.hwnd = hwnd;
			this.alloc = alloc;
			
			hdc = GetDC(hwnd);
			hdcMem = CreateCompatibleDC(hdc);

			stage1Alpha = FlatImageStorage!BGRA8(1, 1, alloc);
			stage2 = alloc.make!(SwappableImage!RGB8)(&stage1Alpha);
			stage2Alpha = alloc.make!(SwappableImage!RGBA8)(&stage1Alpha);

			stage3 = imageObject(stage2, alloc);
			stage3Alpha = imageObject(stage2Alpha, alloc);

			deactivate();
		}

		~this() {
			alloc.dispose(stage2);
			alloc.dispose(stage2Alpha);
			alloc.dispose(stage3);
			alloc.dispose(stage3Alpha);

			DeleteObject(hdc);
		}

		private {
			IAllocator alloc;
			HWND hwnd;
			HDC hdc, hdcMem;

			FlatImageStorage!BGRA8 stage1Alpha = void;

			SwappableImage!RGB8* stage2;
			SwappableImage!RGBA8* stage2Alpha;

			ImageStorage!RGB8 stage3;
			ImageStorage!RGBA8 stage3Alpha;
		}

		override {
			@property {
				ImageStorage!RGB8 vramBuffer() { return stage3; }
				ImageStorage!RGBA8 vramAlphaBuffer() { return stage3Alpha; }
			}

			void activate() {}

			void deactivate() {
				RECT windowRect;
				GetClientRect(hwnd, &windowRect);

				scope(exit) {
					if (windowRect.right != stage2.width || windowRect.bottom != stage2.height)
						stage2.resize(windowRect.right, windowRect.bottom);

					InvalidateRgn(hwnd, null, true);
				}

				if (!IsWindowVisible(hwnd))
					return;

				ubyte* bufferPtr;
				uint bitsCount;
				
				bitsCount = 32;
				bufferPtr = cast(ubyte*)stage1Alpha.__pixelsRawArray.ptr;

				HBITMAP hBitmap = CreateBitmap(cast(uint)stage2.width, cast(uint)stage2.height, 1, bitsCount, cast(void*)bufferPtr);
				
				HGDIOBJ oldBitmap = SelectObject(hdcMem, hBitmap);
				
				HBITMAP bitmap;
				GetObjectA(hBitmap, HBITMAP.sizeof, &bitmap);
				
				StretchBlt(hdc, 0, 0, cast(uint)stage2.width, cast(uint)stage2.height, hdcMem, 0, 0, cast(uint)windowRect.right, cast(uint)windowRect.bottom, SRCCOPY);
				
				SelectObject(hdcMem, oldBitmap);
				DeleteObject(hBitmap);
			}

			bool readyToBeUsed() { return true; }
		}
	}
}

final class VRAMContextImpl_X11 : VRAMContextImpl {
    import stdx.allocator : CAllocatorImpl;
    import stdx.allocator.mallocator : AlignedMallocator;
    import cf.spew.event_loop.wells.x11;

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
        x11b.x11.XSetBackground(x11Display(), graphicGC, x11b.x11.XWhitePixel(x11Display(), screen));
        x11b.x11.XSetForeground(x11Display(), graphicGC, x11b.x11.XBlackPixel(x11Display(), screen));
    }

    ~this() {
        alloc.dispose(stage2);
        alloc.dispose(stage2Alpha);
        alloc.dispose(stage3);
        alloc.dispose(stage3Alpha);

        x11b.x11.XFreeGC(x11Display(), graphicGC);

        if (x11Image !is null) {
            x11b.x11.XDestroyImage(x11Image);
        }

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
            ImageStorage!RGB8 vramBuffer() { return stage3; }
            ImageStorage!RGBA8 vramAlphaBuffer() { return stage3Alpha; }
        }

        void activate() {
            import cf.spew.implementation.windowing.misc;

            auto attributes = x11WindowAttributes(whandle);
            if (attributes.width != stage1Alpha.width || attributes.height != stage1Alpha.height) {
                if (x11Image !is null)
                    x11b.x11.XDestroyImage(x11Image);

                // removes an existing instance without calling the destructor!
                *(&stage1Alpha) = FlatImageStorage!BGRA8(attributes.width, attributes.height, mallocator);
                x11Image = x11b.x11.XCreateImage(x11Display(), cast(x11b.Visual*)graphicGC, 24, x11b.ZPixmap, 0, cast(char*)stage1Alpha.__pixelsRawArray.ptr, attributes.width, attributes.height, 32, 0);
            }
        }

        void deactivate() {
            if (x11Image !is null) {
                x11b.x11.XPutImage(x11Display(), whandle, graphicGC, x11Image, 0, 0, 0, 0, cast(uint)stage1Alpha.width, cast(uint)stage1Alpha.height);
            }
        }

        bool readyToBeUsed() { return true; }
    }
}
