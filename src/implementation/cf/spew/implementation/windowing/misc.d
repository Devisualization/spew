/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.misc;
import cf.spew.ui.display;
import cf.spew.ui.context.defs;
import cf.spew.ui.window.defs;
import cf.spew.ui.rendering : vec2;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8, RGBA8;
import std.experimental.containers.list;
import std.experimental.containers.map;
import stdx.allocator : IAllocator, ISharedAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
import devisualization.util.core.memory.managed;
import x11b = devisualization.bindings.x11;
import derelict.util.sharedlib;
import core.stdc.config : c_long, c_ulong;

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
		winapi.BOOL function(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMonitorCapabilities, winapi.LPDWORD pdwSupportedColorTemperatures) GetMonitorCapabilities;
		winapi.BOOL function(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMinimumBrightness, winapi.LPDWORD pdwCurrentBrightness, winapi.LPDWORD pdwMaximumBrightness) GetMonitorBrightness;
		winapi.BOOL function(winapi.HMONITOR hMonitor, winapi.DWORD dwPhysicalMonitorArraySize, PHYSICAL_MONITOR* pPhysicalMonitorArray) GetPhysicalMonitorsFromHMONITOR;
	}

	SharedLib dxva2;
	static this() {
		import cf.spew.implementation.windowing.misc;
		dxva2.load(["dxva2.dll"]);

		if (dxva2.isLoaded) {
			GetMonitorCapabilities = cast(typeof(GetMonitorCapabilities))dxva2.loadSymbol("GetMonitorCapabilities", false);
			GetMonitorBrightness = cast(typeof(GetMonitorBrightness))dxva2.loadSymbol("GetMonitorCapabilities", false);
			GetPhysicalMonitorsFromHMONITOR = cast(typeof(GetPhysicalMonitorsFromHMONITOR))dxva2.loadSymbol("GetMonitorCapabilities", false);
		}
	}

	static ~this() {
		if (dxva2.isLoaded) {
			dxva2.unload();
		}
	}

	//

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
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObject;

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
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObject;

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

	winapi.HBITMAP imageToAlphaBitmap_WinAPI(shared(ImageStorage!RGBA8) from, winapi.HDC hMemoryDC, shared(ISharedAllocator) alloc) {
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

	winapi.HICON imageToIcon_WinAPI(shared(ImageStorage!RGBA8) from, winapi.HDC hMemoryDC, shared(ISharedAllocator) alloc) {
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
		shared(UIInstance) uiInstance;

		HandleAppender!IDisplay displays;

		void call() {
			displays = HandleAppender!IDisplay(alloc);
			winapi.EnumDisplayMonitors(null, null, &callbackGetDisplays_WinAPI, cast(winapi.LPARAM)cast(void*)&this);
		}
	}

	struct GetPrimaryDisplay_WinAPI {
		import cf.spew.implementation.instance;
		IAllocator alloc;
		shared(UIInstance) uiInstance;

		IDisplay display;

		void call() {
			winapi.EnumDisplayMonitors(null, null, &callbackGetPrimaryDisplay_WinAPI, cast(winapi.LPARAM)cast(void*)&this);
		}
	}

	struct GetWindows_WinAPI {
		import cf.spew.implementation.instance;
		IAllocator alloc;

		shared(UIInstance) uiInstance;
		IDisplay display;

		HandleAppender!IWindow windows;

		void call() {
			windows = HandleAppender!IWindow(alloc);
			winapi.EnumWindows(&callbackGetWindows_WinAPI, cast(winapi.LPARAM)&this);
		}
	}

	extern(Windows) {
		int callbackGetDisplays_WinAPI(winapi.HMONITOR hMonitor, winapi.HDC, winapi.LPRECT, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.display;
			GetDisplays_WinAPI* ctx = cast(GetDisplays_WinAPI*)lParam;

			try {
				DisplayImpl_WinAPI display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc, ctx.uiInstance);
				ctx.displays.add(display);
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
					ctx.windows.add(window);
				} else {
					auto display2 = window.display;
					if (display2 is null) {
						ctx.alloc.dispose(window);
						return true;
					}

					if (display2.name == ctx.display.name)
						ctx.windows.add(window);
					else
						ctx.alloc.dispose(window);
				}
			} catch(Exception e) {}

			return true;
		}
	}
}

struct HandleAppender(Handle) {
	IAllocator alloc;

	Handle[] array;
	size_t toUse;

	void add(Handle handle) {
		if (toUse == 0) {
			if (array.length == 0) {
				alloc.makeArray!Handle(64);
				toUse = 64;
			} else {
				alloc.expandArray(array, 8);
				toUse = 8;
			}
		}

		array[$-(toUse--)] = handle;
	}

	Handle[] get() {
		return array[0 .. $-toUse];
	}

	alias get this;
}

struct GetWindows_X11 {
	import cf.spew.implementation.instance;
	import cf.spew.implementation.windowing.display;
	import devisualization.bindings.x11;
	import cf.spew.event_loop.wells.x11;

	IAllocator alloc;
	shared(UIInstance) uiInstance;
	DisplayImpl_X11 display;

	HandleAppender!IWindow windows;

	void call() {
		windows = HandleAppender!IWindow(alloc);
		Window rootWindow = x11.XDefaultRootWindow(x11Display());
		process(rootWindow);
	}

	private void process(Window rootWindow) {
		import cf.spew.implementation.windowing.window;

		Window unused1, unused2;
		Window* childWindows;
		uint childCount;

		x11.XQueryTree(x11Display(), rootWindow, &unused1, &unused2, &childWindows, &childCount);

		foreach(i; 0 .. childCount) {
			XWindowAttributes attribs;
			x11.XGetWindowAttributes(x11Display(), childWindows[i],&attribs);

			if (display !is null) {
				if ((attribs.x >= display.x && attribs.x < display.x + display.width) &&
					(attribs.y >= display.y && attribs.y < display.y + display.height)) {
					// is on this display
				} else
					continue;
			}

			WindowImpl_X11 window = alloc.make!WindowImpl_X11(childWindows[i], cast(IContext)null, alloc, uiInstance);
			windows.add(window);

			process(childWindows[i]);
		}

		if (childWindows !is null) {
			x11.XFree(childWindows);
		}
	}
}

x11b.XWindowAttributes x11WindowAttributes(x11b.Window window) {
	import devisualization.bindings.x11;
	import cf.spew.event_loop.wells.x11;

	int x, y;
	Window unused;
	XWindowAttributes ret;

	Window rootWindow = x11.XDefaultRootWindow(x11Display());
	x11.XTranslateCoordinates(x11Display(), window, rootWindow, 0, 0, &x, &y, &unused);
	x11.XGetWindowAttributes(x11Display(), window, &ret);

	// fixes the coordinates to the correct root instead of parent.
	ret.x = x - ret.x;
	ret.y = y - ret.y;
	return ret;
}

enum {
	XC_watch = 150,
	XC_hand1 = 58,
	XC_left_ptr = 68,
	XC_X_cursor = 0,
	XC_top_left_corner = 134,
	XC_top_right_corner = 136,
	XC_left_side = 70,
	XC_top_side = 138,
	XC_right_side = 196,
	XC_bottom_left_corner = 12,
	XC_bottom_side = 16,
	XC_bottom_right_corner = 14,
	XC_xterm = 152
}

struct X11WindowProperty {
	import core.stdc.config : c_ulong;

	x11b.Atom type;
	int format;
	c_ulong numberOfItems;
	ubyte* data;
}

X11WindowProperty x11ReadWindowProperty(x11b.Display* display, x11b.Window window, x11b.Atom property) {
	import core.stdc.config : c_ulong;

	c_ulong readByteCount = 1024;
	X11WindowProperty ret;

	while(readByteCount > 0)
	{
		if (ret.data !is null) x11b.x11.XFree(ret.data);
		ret.data = null;
		x11b.x11.XGetWindowProperty(display, window, property, 0, readByteCount, false, x11b.AnyPropertyType, &ret.type,
			&ret.format, &ret.numberOfItems, &readByteCount, &ret.data);
	}

	return ret;
}

struct Motif_WMHints {
    c_ulong Flags;
    c_ulong Functions;
    c_ulong Decorations;
    c_long InputMode;
    c_ulong State;
}

// https://people.gnome.org/~tthurman/docs/metacity/xprops_8h.html#1b63c2b33eb9128fd4ec991bf472502e
enum {
    MWM_HINTS_FUNCTIONS = 1 << 0,
    MWM_HINTS_DECORATIONS = 1 << 1,

    MWM_FUNC_ALL = 1 << 0,
    MWM_FUNC_RESIZE = 1 << 1,
    MWM_FUNC_MOVE = 1 << 2,
    MWM_FUNC_MINIMIZE = 1 << 3,
    MWM_FUNC_MAXIMIZE = 1 << 4,

    MWM_DECOR_ALL = 1 << 0,
    MWM_DECOR_BORDER = 1 << 1,
    MWM_DECOR_RESIZEH = 1 << 2,
    MWM_DECOR_TITLE = 1 << 3,
    MWM_DECOR_MENU = 1 << 4,
    MWM_DECOR_MINIMIZE = 1 << 5,
    MWM_DECOR_MAXIMIZE = 1 << 6
}

enum WindowX11Styles : Motif_WMHints {
    Dialog = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
        MWM_FUNC_RESIZE | MWM_FUNC_MOVE | MWM_FUNC_MINIMIZE | MWM_FUNC_MAXIMIZE,
        MWM_DECOR_BORDER | MWM_DECOR_RESIZEH | MWM_DECOR_TITLE | MWM_DECOR_MINIMIZE | MWM_DECOR_MAXIMIZE),
    Borderless = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
        MWM_FUNC_MOVE,
        MWM_DECOR_MINIMIZE | MWM_DECOR_TITLE),
    Popup = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS,
        MWM_FUNC_MOVE,
        MWM_DECOR_MINIMIZE | MWM_DECOR_BORDER | MWM_DECOR_TITLE),
    Fullscreen = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS, 0, 0),
    NoDecorations = Motif_WMHints(MWM_HINTS_FUNCTIONS | MWM_HINTS_DECORATIONS, 0, 0),
}
