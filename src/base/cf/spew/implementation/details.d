module cf.spew.implementation.details;

public import cf.spew.ui;
public import cf.spew.platform;
public import cf.spew.event_loop;
public import std.experimental.graphic.image : ImageStorage;
public import std.experimental.graphic.color : RGB8, RGBA8;
public import std.experimental.containers.list;
public import std.experimental.containers.map;
public import std.experimental.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
public import std.experimental.memory.managed;

version(Windows) {
	public import winapi = core.sys.windows.windows;

	pragma(lib, "gdi32");
	pragma(lib, "user32");
	
	public import cf.spew.implementation.features.notifications;
	interface PlatformInterfaces : Feature_Notification, Have_Notification {}
} else {
	interface PlatformInterfaces {}
}

abstract class EventLoopConsumerImpl : EventLoopConsumer {
	import cf.spew.implementation.windowing.window;
	import cf.spew.implementation.platform;
	import cf.spew.events.windowing;
	import std.typecons : Nullable;

	PlatformImpl platform;

	this(PlatformImpl platform) {
		this.platform = platform;
	}

	bool processEvent(ref Event event) {
		IWindow window = platform.windowToIdMapper[event.wellData1Value];
		
		if (window is null) {

		} else if (WindowImpl w = cast(WindowImpl)window) {
			switch(event.type) {
				case Windowing_Events_Types.Window_Moved:
					w.onMoveDel(event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
					return true;
				case Windowing_Events_Types.Window_Resized:
					w.onSizeChangeDel(event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
					return true;
				case Windowing_Events_Types.Window_KeyInput:
					w.onKeyEntryDel(event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
					return true;
				case Windowing_Events_Types.Window_CursorScroll:
					w.onScrollDel(event.windowing.scroll.amount);
					return true;
				case Windowing_Events_Types.Window_CursorMoved:
					w.onCursorMoveDel(event.windowing.cursorMoved.newX, event.windowing.cursorMoved.newY);
					return true;
				case Windowing_Events_Types.Window_CursorAction:
					w.onCursorActionDel(event.windowing.cursorAction.action);
					return true;
				case Windowing_Events_Types.Window_CursorActionEnd:
					w.onCursorActionEndDel(event.windowing.cursorAction.action);
					return true;

				case Windowing_Events_Types.Window_CursorActionDo:
				case Windowing_Events_Types.Window_Focused:
				case Windowing_Events_Types.Window_KeyDown:
				case Windowing_Events_Types.Window_KeyUp:
				default:
					return false;
			}
		}
		
		return false;
	}
	
	@property {
		Nullable!EventSource pairOnlyWithSource() { return Nullable!EventSource(); }

		EventType pairOnlyWithEvents() { return EventType.all; }

		byte priority() { return 127; }

		string description() { return null; }
	}
}

version(Windows) {
	class EventLoopConsumerImpl_WinAPI : EventLoopConsumerImpl {
		import cf.spew.implementation.platform;
		import cf.spew.implementation.windowing.window;
		import cf.spew.events.windowing;
		import cf.spew.events.winapi;

		this(PlatformImpl platform) {
			super(platform);
		}

		override bool processEvent(ref Event event) {
			IWindow window = platform.windowToIdMapper[event.wellData1Value];

			if (window is null) {

			} else if (WindowImpl_WinAPI w = cast(WindowImpl_WinAPI)window) {
				WindowImpl w2 = cast(WindowImpl)w;
				switch(event.type) {
					case Windowing_Events_Types.Window_Resized:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						w2.onSizeChangeDel(event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
						return true;
					case Windowing_Events_Types.Window_Moved:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						w2.onMoveDel(event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
						return true;

					case WinAPI_Events_Types.Window_Create:
						return false;
					case WinAPI_Events_Types.Window_Destroy:
						return false;
					case WinAPI_Events_Types.Window_Quit:
						return false;
					case WinAPI_Events_Types.Window_GainedKeyboardFocus:
						return false;
					case WinAPI_Events_Types.Window_LostKeyboardFocus:
						return false;
					case WinAPI_Events_Types.Window_Enable:
						return false;
					case WinAPI_Events_Types.Window_Disable:
						return false;
					case WinAPI_Events_Types.Window_SetRedraw:
						return false;
					case WinAPI_Events_Types.Window_Paint:
						return false;
					case WinAPI_Events_Types.Window_SystemColorsChanged:
						return false;
					case WinAPI_Events_Types.Window_DevModeChanged:
						return false;
					case WinAPI_Events_Types.Window_SetCursor:
						return false;
					case WinAPI_Events_Types.Window_EnterSizeMove:
						return false;
					case WinAPI_Events_Types.Window_ExitSizeMove:
						return false;
					case WinAPI_Events_Types.Window_RequestClose:
						return false;

					default:
						break;
				}
			}

			if (super.processEvent(event))
				return true;
			else
				return false;
		}

		@property {
			bool onMainThread() { return true; }
			bool onAdditionalThreads() { return true; }
		}
	}

	struct PHYSICAL_MONITOR {
		winapi.HANDLE hPhysicalMonitor;
		winapi.WCHAR[PHYSICAL_MONITOR_DESCRIPTION_SIZE] szPhysicalMonitorDescription;
	}

	enum WindowDWStyles : winapi.DWORD {
		Dialog = winapi.WS_OVERLAPPED | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_THICKFRAME | winapi.WS_MINIMIZEBOX | winapi.WS_MAXIMIZEBOX,
		DialogEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW,
		
		Borderless = winapi.WS_OVERLAPPED | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_BORDER | winapi.WS_MINIMIZEBOX,
		BorderlessEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW,
		
		Popup = winapi.WS_POPUPWINDOW | winapi.WS_CAPTION | winapi.WS_SYSMENU | winapi.WS_BORDER | winapi.WS_MINIMIZEBOX,
		PopupEx = winapi.WS_EX_ACCEPTFILES | winapi.WS_EX_APPWINDOW | winapi.WS_EX_TOPMOST,
		
		Fullscreen = winapi.WS_POPUP | winapi.WS_CLIPCHILDREN | winapi.WS_CLIPSIBLINGS,
		FullscreenEx = winapi.WS_EX_APPWINDOW | winapi.WS_EX_TOPMOST
	}

	static wstring ClassNameW = __MODULE__ ~ ":Class"w;

	enum {
		PHYSICAL_MONITOR_DESCRIPTION_SIZE = 128,
		MC_CAPS_BRIGHTNESS = 0x00000002
	}

	extern(Windows) {
		// dxva2
		winapi.BOOL GetMonitorCapabilities(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMonitorCapabilities, winapi.LPDWORD pdwSupportedColorTemperatures);
		winapi.BOOL GetMonitorBrightness(winapi.HANDLE hMonitor, winapi.LPDWORD pdwMinimumBrightness, winapi.LPDWORD pdwCurrentBrightness, winapi.LPDWORD pdwMaximumBrightness);
		winapi.BOOL GetPhysicalMonitorsFromHMONITOR(winapi.HMONITOR hMonitor, winapi.DWORD dwPhysicalMonitorArraySize, PHYSICAL_MONITOR* pPhysicalMonitorArray);
	}

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
			
			buffer[i] = c.b;
			buffer[i+1] = c.g;
			buffer[i+2] = c.r;
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
			
			buffer[i] = c.b;
			buffer[i+1] = c.g;
			buffer[i+2] = c.r;
			buffer[i+3] = c.a;
			
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

	struct GetDisplays {
		import cf.spew.implementation.platform;
		IAllocator alloc;
		PlatformImpl platform;
		
		IDisplay[] displays;
		
		void call() {
			winapi.EnumDisplayMonitors(null, null, &callbackGetDisplays, cast(winapi.LPARAM)cast(void*)&this);
		}
	}
	
	struct GetWindows {
		import cf.spew.implementation.platform;
		IAllocator alloc;
		
		PlatformImpl platform;
		IDisplay display;
		
		IWindow[] windows;
		
		void call() {
			winapi.EnumWindows(&callbackGetWindows, cast(winapi.LPARAM)&this);
		}
	}
	
	extern(Windows) {
		int callbackGetDisplays(winapi.HMONITOR hMonitor, winapi.HDC, winapi.LPRECT, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.display;
			GetDisplays* ctx = cast(GetDisplays*)lParam;
			
			try {
				DisplayImpl_WinAPI display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc, ctx.platform);
				ctx.alloc.expandArray(ctx.displays, 1);
				ctx.displays[$-1] = display;
			} catch (Exception e) {}
			
			return true;
		}
		
		int callbackGetWindows(winapi.HWND hwnd, winapi.LPARAM lParam) nothrow {
			import cf.spew.implementation.windowing.window;
			GetWindows* ctx = cast(GetWindows*)lParam;
			
			if (!winapi.IsWindowVisible(hwnd))
				return true;
			
			winapi.RECT rect;
			winapi.GetWindowRect(hwnd, &rect);
			
			if (rect.right - rect.left == 0 || rect.bottom - rect.top == 0)
				return true;
			
			try {
				WindowImpl_WinAPI window = ctx.alloc.make!WindowImpl_WinAPI(hwnd, cast(IContext)null, ctx.alloc, ctx.platform);
				
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