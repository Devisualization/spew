/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.contexts.vram;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features.vram;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8, RGBA8;
import std.experimental.allocator : IAllocator, make, dispose;

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
	import devisualization.image.interfaces : SwappableImage, imageObject;
	import std.experimental.color.rgb : BGR8, BGRA8;
	import devisualization.image.storage.flat;

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