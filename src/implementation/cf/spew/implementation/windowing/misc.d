module cf.spew.implementation.windowing.misc;
import cf.spew.ui.display;
import cf.spew.ui.context.defs;
import cf.spew.ui.window.defs;

version(Windows) {
	public import winapi = core.sys.windows.windows;

	enum WindowDWStyles : winapi.DWORD {
		Dialog = winapi.WS_OVERLAPPED | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_THICKFRAME | winapi.WS_MINIMIZEBOX | winapi.WS_MAXIMIZEBOX,
		DialogEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW,
		
		Borderless = winapi.WS_OVERLAPPED | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_BORDER | winapi.WS_MINIMIZEBOX,
		BorderlessEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW,
		
		Popup = winapi.WS_POPUPWINDOW | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_BORDER | winapi.WS_MINIMIZEBOX,
		PopupEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW | winapi.WS_EX_TOPMOST,
		
		Fullscreen = winapi.WS_POPUP | winapi.WS_CLIPCHILDREN | winapi.WS_CLIPSIBLINGS,
		FullscreenEx = winapi.WS_EX_APPWINDOW | winapi.WS_EX_TOPMOST,

		NoDecorations = winapi.WS_POPUP,
		NoDecorationsEx = winapi.WS_EX_TOPMOST | winapi.WS_EX_TRANSPARENT
	}

	static wstring ClassNameW = __MODULE__ ~ ":Class"w;

	struct PHYSICAL_MONITOR {
		winapi.HANDLE hPhysicalMonitor;
		winapi.WCHAR[PHYSICAL_MONITOR_DESCRIPTION_SIZE] szPhysicalMonitorDescription;
	}

	enum {
		PHYSICAL_MONITOR_DESCRIPTION_SIZE = 128,
		MC_CAPS_BRIGHTNESS = 0x00000002,

		NOTIFYICON_VERSION_4 = 4,
		NIF_SHOWTIP = 0x00000080,
		NIF_REALTIME = 0x00000040,
	}

	extern(Windows) {
		// dxva2
		winapi.BOOL GetMonitorCapabilities(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMonitorCapabilities, winapi.LPDWORD pdwSupportedColorTemperatures);
		winapi.BOOL GetMonitorBrightness(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMinimumBrightness, winapi.LPDWORD pdwCurrentBrightness, winapi.LPDWORD pdwMaximumBrightness);
		winapi.BOOL GetPhysicalMonitorsFromHMONITOR(winapi.HMONITOR hMonitor, winapi.DWORD dwPhysicalMonitorArraySize, PHYSICAL_MONITOR* pPhysicalMonitorArray);
	}

	//

	import cf.spew.ui.rendering : vec2;
	import std.experimental.graphic.image : ImageStorage;
	import std.experimental.graphic.color : RGB8, RGBA8;
	import std.experimental.containers.list;
	import std.experimental.containers.map;
	import std.experimental.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
	import std.experimental.memory.managed;

	ImageStorage!RGB8 screenshotImpl_WinAPI(IAllocator alloc, winapi.HDC hFrom, uint width, uint height) {
		winapi.HDC hMemoryDC = winapi.CreateCompatibleDC(hFrom);
		winapi.HBITMAP hBitmap = winapi.CreateCompatibleBitmap(hFrom, width, height);
		
		winapi.HBITMAP hOldBitmap = winapi.SelectObject(hMemoryDC, hBitmap);
		winapi.BitBlt(hMemoryDC, 0, 0, width, height, hFrom, 0, 0, winapi.SRCCOPY);
		
		auto storage = bitmapToImage_WinAPI(hBitmap, hMemoryDC, vec2!size_t(width, height), alloc);
		
		hBitmap = winapi.SelectObject(hMemoryDC, hOldBitmap);
		winapi.DeleteDC(hMemoryDC);
		
		return storage;
	}
	
	ImageStorage!RGB8 bitmapToImage_WinAPI(winapi.HBITMAP hBitmap, winapi.HDC hMemoryDC, vec2!size_t size_, IAllocator alloc) {
		import std.experimental.graphic.image.storage.base : ImageStorageHorizontal;
		import std.experimental.graphic.image.interfaces : imageObject;
		
		size_t dwBmpSize = ((size_.x * 32 + 31) / 32) * 4 * size_.y;
		ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
		auto storage = imageObject!(ImageStorageHorizontal!RGB8)(size_.x, size_.y, alloc);
		
		winapi.BITMAPINFOHEADER bi;
		
		bi.biSize = winapi.BITMAPINFOHEADER.sizeof;
		bi.biWidth = cast(int)size_.x;
		bi.biHeight = cast(int)size_.y;
		bi.biPlanes = 1;
		bi.biBitCount = 32;
		bi.biCompression = winapi.BI_RGB;
		bi.biSizeImage = 0;
		bi.biXPelsPerMeter = 0;
		bi.biYPelsPerMeter = 0;
		bi.biClrUsed = 0;
		bi.biClrImportant = 0;
		
		winapi.BITMAPINFO bitmapInfo;
		bitmapInfo.bmiHeader = bi;
		
		winapi.GetDIBits(hMemoryDC, hBitmap, 0, cast(int)size_.y, buffer.ptr, &bitmapInfo, winapi.DIB_RGB_COLORS);
		
		size_t x;
		size_t y = size_.y-1;
		for(size_t i = 0; i < buffer.length; i += 4) {
			RGB8 c = RGB8(buffer[i+2], buffer[i+1], buffer[i]);
			
			storage[x, y] = c;
			
			x++;
			if (x == size_.x) {
				x = 0;
				if (y == 0)
					break;
				y--;
			}
		}
		
		alloc.dispose(buffer);
		return storage;
	}
	
	ImageStorage!RGBA8 bitmapToAlphaImage_WinAPI(winapi.HBITMAP hBitmap, winapi.HDC hMemoryDC, vec2!size_t size_, IAllocator alloc) {
		import std.experimental.graphic.image.storage.base : ImageStorageHorizontal;
		import std.experimental.graphic.image.interfaces : imageObject;
		
		size_t dwBmpSize = ((size_.x * 32 + 31) / 32) * 4 * size_.y;
		ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
		auto storage = imageObject!(ImageStorageHorizontal!RGBA8)(size_.x, size_.y, alloc);
		
		winapi.BITMAPINFOHEADER bi;
		
		bi.biSize = winapi.BITMAPINFOHEADER.sizeof;
		bi.biWidth = cast(int)size_.x;
		bi.biHeight = cast(int)size_.y;
		bi.biPlanes = 1;
		bi.biBitCount = 32;
		bi.biCompression = winapi.BI_RGB;
		bi.biSizeImage = 0;
		bi.biXPelsPerMeter = 0;
		bi.biYPelsPerMeter = 0;
		bi.biClrUsed = 0;
		bi.biClrImportant = 0;
		
		winapi.BITMAPINFO bitmapInfo;
		bitmapInfo.bmiHeader = bi;
		
		winapi.GetDIBits(hMemoryDC, hBitmap, 0, cast(int)size_.y, buffer.ptr, &bitmapInfo, winapi.DIB_RGB_COLORS);
		
		size_t x;
		size_t y = size_.y-1;
		for(size_t i = 0; i < buffer.length; i += 4) {
			RGBA8 c = RGBA8(buffer[i+2], buffer[i+1], buffer[i], 255);
			
			storage[x, y] = c;
			
			x++;
			if (x == size_.x) {
				x = 0;
				if (y == 0)
					break;
				y--;
			}
		}
		
		alloc.dispose(buffer);
		return storage;
	}
	
	winapi.HBITMAP imageToBitmap_WinAPI(ImageStorage!RGB8 from, winapi.HDC hMemoryDC, IAllocator alloc) {
		size_t dwBmpSize = ((from.width * 32 + 31) / 32) * 4 * from.height;
		ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
		
		winapi.HICON ret;
		
		size_t x;
		size_t y = from.height-1;
		for(size_t i = 0; i < buffer.length; i += 4) {
			RGB8 c = from[x, y];
			
			buffer[i] = c.b.value;
			buffer[i+1] = c.g.value;
			buffer[i+2] = c.r.value;
			buffer[i+3] = 255;
			
			x++;
			if (x == from.width) {
				x = 0;
				if (y == 0)
					break;
				y--;
			}
		}
		
		winapi.HBITMAP hBitmap = winapi.CreateBitmap(cast(uint)from.width, cast(uint)from.height, 1, 32, buffer.ptr);
		alloc.dispose(buffer);
		return hBitmap;
	}
	
	winapi.HBITMAP imageToAlphaBitmap_WinAPI(ImageStorage!RGBA8 from, winapi.HDC hMemoryDC, IAllocator alloc) {
		size_t dwBmpSize = ((from.width * 32 + 31) / 32) * 4 * from.height;
		ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
		
		winapi.HICON ret;
		
		size_t x;
		size_t y = from.height-1;
		for(size_t i = 0; i < buffer.length; i += 4) {
			RGBA8 c = from[x, y];
			
			buffer[i] = c.b.value;
			buffer[i+1] = c.g.value;
			buffer[i+2] = c.r.value;
			buffer[i+3] = c.a.value;
			
			x++;
			if (x == from.width) {
				x = 0;
				if (y == 0)
					break;
				y--;
			}
		}
		
		winapi.HBITMAP hBitmap = winapi.CreateBitmap(cast(uint)from.width, cast(uint)from.height, 1, 32, buffer.ptr);
		alloc.dispose(buffer);
		return hBitmap;
	}
	
	winapi.HICON imageToIcon_WinAPI(ImageStorage!RGBA8 from, winapi.HDC hMemoryDC, IAllocator alloc) {
		winapi.HBITMAP hBitmap = imageToAlphaBitmap_WinAPI(from, hMemoryDC, alloc);
		winapi.HICON ret = bitmapToIcon_WinAPI(hBitmap, hMemoryDC, vec2!size_t(from.width, from.height));
		
		scope(exit)
			winapi.DeleteObject(hBitmap);
		
		return ret;
	}
	
	winapi.HICON bitmapToIcon_WinAPI(winapi.HBITMAP hBitmap, winapi.HDC hMemoryDC, vec2!size_t size_) {
		winapi.HICON ret;
		winapi.HBITMAP hbmMask = winapi.CreateCompatibleBitmap(hMemoryDC, cast(uint)size_.x, cast(uint)size_.y);
		
		winapi.ICONINFO ii;
		ii.fIcon = true;
		ii.hbmColor = hBitmap;
		ii.hbmMask = hbmMask;
		
		ret = winapi.CreateIconIndirect(&ii);
		
		winapi.DeleteObject(hbmMask);
		
		return ret;
	}
	
	winapi.HBITMAP resizeBitmap_WinAPI(winapi.HBITMAP hBitmap, winapi.HDC hDC, vec2!size_t toSize, vec2!size_t fromSize) {
		winapi.HDC hMemDC1 = winapi.CreateCompatibleDC(hDC);
		winapi.HBITMAP hBitmap1 = winapi.CreateCompatibleBitmap(hDC, cast(int)toSize.x, cast(int)toSize.y);
		winapi.HGDIOBJ hOld1 = winapi.SelectObject(hMemDC1, hBitmap1);
		
		winapi.HDC hMemDC2 = winapi.CreateCompatibleDC(hDC);
		winapi.HGDIOBJ hOld2 = winapi.SelectObject(hMemDC2, hBitmap);
		
		winapi.BITMAP bitmap;
		winapi.GetObjectW(hBitmap, winapi.BITMAP.sizeof, &bitmap);
		
		winapi.StretchBlt(hMemDC1, 0, 0, cast(int)toSize.x, cast(int)toSize.y, hMemDC2, 0, 0, cast(int)fromSize.x, cast(int)fromSize.y, winapi.SRCCOPY);
		
		winapi.SelectObject(hMemDC1, hOld1);
		winapi.SelectObject(hMemDC2, hOld2);
		winapi.DeleteDC(hMemDC1);
		winapi.DeleteDC(hMemDC2);
		
		return hBitmap1;
	}

	struct GetDisplays_WinAPI {
		import cf.spew.implementation.instance;
		IAllocator alloc;
		UIInstance uiInstance;
		
		IDisplay[] displays;

		void call() {
			winapi.EnumDisplayMonitors(null, null, &callbackGetDisplays_WinAPI, cast(winapi.LPARAM)cast(void*)&this);
		}
	}

	struct GetPrimaryDisplay_WinAPI {
		import cf.spew.implementation.instance;
		IAllocator alloc;
		UIInstance uiInstance;
		
		IDisplay display;
		
		void call() {
			winapi.EnumDisplayMonitors(null, null, &callbackGetPrimaryDisplay_WinAPI, cast(winapi.LPARAM)cast(void*)&this);
		}
	}
	
	struct GetWindows_WinAPI {
		import cf.spew.implementation.instance;
		IAllocator alloc;
		
		UIInstance uiInstance;
		IDisplay display;
		
		IWindow[] windows;
		
		void call() {
			winapi.EnumWindows(&callbackGetWindows_WinAPI, cast(winapi.LPARAM)&this);
		}
	}
	
	extern(Windows) {
		int callbackGetDisplays_WinAPI(winapi.HMONITOR hMonitor, winapi.HDC, winapi.LPRECT, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.display;
			GetDisplays_WinAPI* ctx = cast(GetDisplays_WinAPI*)lParam;

			try {
				DisplayImpl_WinAPI display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc, ctx.uiInstance);
				ctx.alloc.expandArray(ctx.displays, 1);
				ctx.displays[$-1] = display;
			} catch (Exception e) {}
			
			return true;
		}

		int callbackGetPrimaryDisplay_WinAPI(winapi.HMONITOR hMonitor, winapi.HDC, winapi.LPRECT, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.display;
			GetPrimaryDisplay_WinAPI* ctx = cast(GetPrimaryDisplay_WinAPI*)lParam;
			
			winapi.MONITORINFOEXA info;
			info.cbSize = winapi.MONITORINFOEXA.sizeof;
			winapi.GetMonitorInfoA(hMonitor, &info);
			
			if ((info.dwFlags & winapi.MONITORINFOF_PRIMARY) != winapi.MONITORINFOF_PRIMARY) {
				return true;
			}
			
			try {
				ctx.display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc, ctx.uiInstance);
				return false;
			} catch (Exception e) {}
			return true;
		}
		
		int callbackGetWindows_WinAPI(winapi.HWND hwnd, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.window;
			GetWindows_WinAPI* ctx = cast(GetWindows_WinAPI*)lParam;
			
			if (!winapi.IsWindowVisible(hwnd))
				return true;
			
			winapi.RECT rect;
			winapi.GetWindowRect(hwnd, &rect);
			
			if (rect.right - rect.left == 0 || rect.bottom - rect.top == 0)
				return true;
			
			try {
				WindowImpl_WinAPI window = ctx.alloc.make!WindowImpl_WinAPI(hwnd, cast(IContext)null, ctx.alloc, ctx.uiInstance);
				
				if (ctx.display is null) {
					ctx.alloc.expandArray(ctx.windows, 1);
					ctx.windows[$-1] = window;
				} else {
					auto display2 = window.display;
					if (display2 is null) {
						ctx.alloc.dispose(window);
						return true;
					}
					
					if (display2.name == ctx.display.name) {
						ctx.alloc.expandArray(ctx.windows, 1);
						ctx.windows[$-1] = window;
					} else
						ctx.alloc.dispose(window);
				}
			} catch(Exception e) {}
			
			return true;
		}
	}
}