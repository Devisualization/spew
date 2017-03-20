module cf.spew.implementation.windowing.window;
import cf.spew.implementation.windowing.misc;
import cf.spew.implementation.instance;
import cf.spew.implementation.windowing.display;
import cf.spew.implementation.windowing.menu;
import cf.spew.ui;
import cf.spew.events.windowing;
import std.experimental.allocator : IAllocator, make, makeArray, dispose;
import std.experimental.memory.managed;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGBA8, RGB8;

abstract class WindowImpl : IWindow, IWindowEvents {
	package(cf.spew.implementation) {
		UIInstance instance;
		IAllocator alloc;
		IContext context_;

		bool ownedByProcess;

		EventOnCursorMoveDel onCursorMoveDel;
		EventOnCursorActionDel onCursorActionDel, onCursorActionEndDel;
		EventOnScrollDel onScrollDel;
		EventOnKeyDel onKeyEntryDel;
		EventOnSizeChangeDel onSizeChangeDel;
		EventOnMoveDel onMoveDel;

		EventOnForcedDrawDel onDrawDel;
		EventOnCloseDel onCloseDel;
		EventOnRequestCloseDel onRequestCloseDel;
	}
	
	this(UIInstance instance, bool processOwns) {
		this.instance = instance;
		this.ownedByProcess = processOwns;

		if (processOwns)
			instance.windowToIdMapper[cast(size_t)__handle] = this;
	}

	~this() {
		if (ownedByProcess)
			instance.windowToIdMapper.remove(cast(size_t)__handle);
	}

	@property {
		bool visible() { return renderable; }
		IRenderEvents events() { return this; }
		IWindowEvents windowEvents() { return this; }
		IAllocator allocator() { return alloc; }
		IContext context() { return context_; }

		void onForcedDraw(EventOnForcedDrawDel del) { onDrawDel = del; }
		void onCursorMove(EventOnCursorMoveDel del) { onCursorMoveDel = del; }
		void onCursorAction(EventOnCursorActionDel del) { onCursorActionDel = del; }
		void onCursorActionEnd(EventOnCursorActionDel del) { onCursorActionEndDel = del; }
		void onScroll(EventOnScrollDel del) { onScrollDel = del; }
		void onClose(EventOnCloseDel del) { onCloseDel = del; }
		void onKeyEntry(EventOnKeyDel del) { onKeyEntryDel = del; }
		void onSizeChange(EventOnSizeChangeDel del) { onSizeChangeDel = del; }
		
		void onMove(EventOnMoveDel del) { onMoveDel = del; }
		void onRequestClose(EventOnRequestCloseDel del) { onRequestCloseDel = del; }
	}
}

version(Windows) {
	final class WindowImpl_WinAPI : WindowImpl,
	Feature_ScreenShot, Feature_Icon, Feature_Menu, Feature_Cursor, Feature_Style,
	Have_ScreenShot, Have_Icon, Have_Menu, Have_Cursor, Have_Style {

		import cf.spew.event_loop.wells.winapi;
		import std.traits : isSomeString;
		import std.utf : codeLength, byDchar, byWchar;
		import std.experimental.containers.list;
		import std.experimental.containers.map;
		import core.sys.windows.windows;

		package(cf.spew.implementation) {
			HWND hwnd;
			HMENU hMenu;
			HCURSOR hCursor;

			RECT oldCursorClipArea;

			// this is very high up in field orders, that way this classes data will be in cache when accessed
			EventLoopAlterationCallbacks impl_callbacks_struct;

			List!MenuItem menuItems = void;
			uint menuItemsCount;
			Map!(uint, MenuCallback) menuCallbacks = void;
			
			bool redrawMenu;
			WindowStyle windowStyle;
			
			WindowCursorStyle cursorStyle;
			ImageStorage!RGBA8 customCursor;
		}


		@disable this(UIInstance instance);

		this(HWND hwnd, IContext context, IAllocator alloc, UIInstance instance, HMENU hMenu=null, bool processOwns=false) {
			this.hwnd = hwnd;
			this.alloc = alloc;
			this.context_ = context;
			this.hMenu = hMenu;

			super(instance, processOwns);

			menuItems = List!MenuItem(alloc);
			menuCallbacks = Map!(uint, MenuCallback)(alloc);
			menuItemsCount = 9000;
			
			if (processOwns)
				hCursor = LoadImageW(null, cast(wchar*)IDC_APPSTARTING, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
			else
				cursorStyle = WindowCursorStyle.Underterminate;
		}
		
		~this() {
			if (menuItems.length > 0) {
				foreach(item; menuItems) {
					item.remove();
				}
			}
		}

		@property {
			vec2!uint size() {
				if (!visible)
					return vec2!uint(0, 0);
				
				RECT rect;
				GetClientRect(hwnd, &rect);
				
				if (rect.right < 0 || rect.bottom < 0)
					return vec2!uint(0, 0);
				
				return vec2!uint(rect.right, rect.bottom);
			}

			managed!IDisplay display() {
				import std.typecons : tuple;
				
				HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONULL);
				if (monitor is null)
					return (managed!IDisplay).init;
				else
					return cast(managed!IDisplay)managed!DisplayImpl_WinAPI(managers(), tuple(monitor, alloc, instance), alloc);
			}

			bool renderable() { return IsWindowVisible(hwnd) == 1; }

			void* __handle() { return hwnd; }
		}

		void close() { CloseWindow(hwnd); }

		@property {
			managed!dstring title() {
				int textLength = GetWindowTextLengthW(hwnd);
				wchar[] buffer = alloc.makeArray!wchar(textLength + 1);
				GetWindowTextW(hwnd, buffer.ptr, cast(int)buffer.length);
				
				// what is allocated could potentially be _more_ then required
				dchar[] buffer2 = alloc.makeArray!dchar(codeLength!char(buffer));
				
				size_t i;
				foreach(c; buffer.byDchar) {
					buffer2[i] = c;
					i++;
				}
				
				alloc.dispose(buffer);
				return managed!dstring(cast(dstring)buffer2, managers(), Ownership.Secondary, alloc);
			}
			
			void title(string text) { setTitle(text); }
			void title(wstring text) { setTitle(text); }
			void title(dstring text) { setTitle(text); }
			
			void setTitle(String)(String text) if (isSomeString!String) {
				wchar[] buffer = alloc.makeArray!wchar(codeLength!wchar(text) + 1);
				buffer[$-1] = 0;
				
				size_t i;
				foreach(c; text.byWchar) {
					buffer[i] = c;
					i++;
				}
				
				SetWindowTextW(hwnd, buffer.ptr);
				alloc.dispose(buffer);
			}

			void location(vec2!int point) {
				SetWindowPos(hwnd, null, point.x, point.y, 0, 0, SWP_NOSIZE);
			}

			vec2!int location() {
				RECT rect;
				GetWindowRect(hwnd, &rect);
				return vec2!int(rect.left, rect.top);
			}

			void size(vec2!uint point) {
				RECT rect;
				rect.top = point.x;
				rect.bottom = point.y;
				
				assert(AdjustWindowRectEx(&rect, GetWindowLongA(hwnd, GWL_STYLE), GetMenu(hwnd) !is null, GetWindowLongA(hwnd, GWL_EXSTYLE)));
				SetWindowPos(hwnd, null, 0, 0, rect.right, rect.bottom, SWP_NOMOVE);
			}
		}

		void hide() {
			ShowWindow(hwnd, SW_HIDE);
		}
		
		void show() {
			ShowWindow(hwnd, SW_SHOW);
			UpdateWindow(hwnd);
		}

		Feature_ScreenShot __getFeatureScreenShot() {
			return this;
		}
		
		ImageStorage!RGB8 screenshot(IAllocator alloc=null) {
			if (alloc is null)
				alloc = this.alloc;
			
			auto sizet = size();
			if (sizet.x < 0 || sizet.y < 0)
				return null;
			
			HDC hWindowDC = GetDC(hwnd);
			auto storage = screenshotImpl_WinAPI(alloc, hWindowDC, sizet.x, sizet.y);
			ReleaseDC(hwnd, hWindowDC);
			
			return storage;
		}
		
		Feature_Icon __getFeatureIcon() {
			return this;
		}
		
		ImageStorage!RGBA8 getIcon() @property {
			HICON hIcon = cast(HICON)GetClassLongA(hwnd, GCL_HICON);
			ICONINFO iconinfo;
			GetIconInfo(hIcon, &iconinfo);
			HBITMAP hBitmap = iconinfo.hbmColor;
			
			BITMAP bm;
			GetObjectA(hBitmap, BITMAP.sizeof, &bm);
			
			HDC hFrom = GetDC(null);
			HDC hMemoryDC = CreateCompatibleDC(hFrom);
			
			scope(exit) {
				DeleteDC(hMemoryDC);
				ReleaseDC(null, hFrom);
			}
			
			return bitmapToAlphaImage_WinAPI(hBitmap, hMemoryDC, vec2!size_t(bm.bmWidth, bm.bmHeight), alloc);
		}
		
		void setIcon(ImageStorage!RGBA8 from) @property {
			HICON hIcon = cast(HICON)GetClassLongA(hwnd, GCL_HICON);
			if (hIcon)
				DestroyIcon(hIcon);
			
			HDC hFrom = GetDC(null);
			HDC hMemoryDC = CreateCompatibleDC(hFrom);
			
			hIcon = imageToIcon_WinAPI(from, hMemoryDC, alloc);
			
			if (hIcon) {
				SendMessageA(hwnd, WM_SETICON, cast(WPARAM)ICON_BIG, cast(LPARAM)hIcon);
				SendMessageA(hwnd, WM_SETICON, cast(WPARAM)ICON_SMALL, cast(LPARAM)hIcon);
			}
			
			DeleteDC(hMemoryDC);
			ReleaseDC(null, hFrom);
		}
		
		Feature_Menu __getFeatureMenu() {
			if (hMenu is null)
				return null;
			else
				return this;
		}
		
		MenuItem addItem() {
			auto ret = cast(MenuItem)alloc.make!MenuItemImpl_WinAPI(this, hMenu, null);
			
			menuItems ~= ret;
			return ret;
		}
		
		@property managed!(MenuItem[]) items() {
			auto ret = menuItems.opSlice();
			return cast(managed!(MenuItem[]))ret;
		}
		
		Feature_Cursor __getFeatureCursor() {
			return this;
		}
		
		void setCursor(WindowCursorStyle style) {
			assert(cursorStyle != WindowCursorStyle.Underterminate);
			
			if (cursorStyle == WindowCursorStyle.Custom) {
				// unload systemy stuff
				DestroyCursor(hCursor);
				//FIXME: alloc.dispose(customCursor);
			}
			
			cursorStyle = style;
			
			if (style != WindowCursorStyle.Custom) {
				// load up reference to system one
				
				switch(style) {
					case WindowCursorStyle.Busy:
						hCursor = LoadImageW(null, cast(wchar*)IDC_WAIT, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.Hand:
						hCursor = LoadImageW(null, cast(wchar*)IDC_HAND, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.NoAction:
						hCursor = LoadImageW(null, cast(wchar*)IDC_NO, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeCornerLeft:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENESW, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeCornerRight:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENWSE, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeHorizontal:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZEWE, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeVertical:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENS, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.None:
						hCursor = null;
						break;
					case WindowCursorStyle.Standard:
					default:
						hCursor = LoadImageW(null, cast(wchar*)IDC_ARROW, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
				}
			}
		}
		
		WindowCursorStyle getCursor() {
			return cursorStyle;
		}
		
		void setCustomCursor(ImageStorage!RGBA8 image) {
			import std.experimental.graphic.image.storage.base : ImageStorageHorizontal;
			import std.experimental.graphic.image.interfaces : imageObjectFrom;
			
			assert(cursorStyle != WindowCursorStyle.Underterminate);
			
			// The comments here specify the preferred way to do this.
			// Unfortunately at the time of writing, it is not possible to
			//  use std.experimental.graphic.image for resizing.
			
			setCursor(WindowCursorStyle.Custom);
			
			HDC hFrom = GetDC(null);
			HDC hMemoryDC = CreateCompatibleDC(hFrom);
			
			// duplicate image, store
			customCursor = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(image, alloc);
			
			// customCursor must be a set size, as defined by:
			vec2!size_t toSize = vec2!size_t(GetSystemMetrics(SM_CXCURSOR), GetSystemMetrics(SM_CYCURSOR));
			
			// so customCursor must be resized to the given size
			
			// load systemy copy of image
			// imageToIcon
			
			HBITMAP hBitmap = imageToAlphaBitmap_WinAPI(image, hMemoryDC, alloc);
			HBITMAP hBitmap2 = resizeBitmap_WinAPI(hBitmap, hMemoryDC, toSize, vec2!size_t(image.width, image.height));
			HICON hIcon = bitmapToIcon_WinAPI(hBitmap2, hMemoryDC, toSize);
			
			// GetIconInfo
			
			ICONINFO ii;
			GetIconInfo(hIcon, &ii);
			
			// CreateCursor
			
			hCursor = CreateCursor(null, ii.xHotspot, ii.yHotspot, cast(int)toSize.x, cast(int)toSize.y, ii.hbmColor, ii.hbmMask);
			
			DeleteObject(hBitmap);
			DeleteObject(hBitmap2);
			DeleteDC(hMemoryDC);
			ReleaseDC(null, hFrom);
		}
		
		ImageStorage!RGBA8 getCursorIcon() {
			return customCursor;
		}

		bool lockCursorToWindow() {
			GetClipCursor(&oldCursorClipArea);
			RECT myRect;
			GetClientRect(hwnd, &myRect);
			MapWindowPoints(hwnd, GetParent(hwnd), cast(POINT*)&myRect, 2);

			if (ClipCursor(&myRect) == 0) {
				oldCursorClipArea = RECT.init;
				return false;
			} else
				return true;
		}

		void unlockCursorFromWindow() {
			if (oldCursorClipArea != RECT.init)
				ClipCursor(&oldCursorClipArea);
		}
		
		Feature_Style __getFeatureStyle() {
			return this;
		}
		
		void setStyle(WindowStyle style) {
			windowStyle = style;
			
			RECT rect;
			DWORD dwStyle, dwExStyle;
			
			switch(style) {
				case WindowStyle.Fullscreen:
					dwStyle = WindowDWStyles.Fullscreen;
					dwExStyle = WindowDWStyles.FullscreenEx;
					break;
					
				case WindowStyle.Popup:
					dwStyle = WindowDWStyles.Popup;
					dwExStyle = WindowDWStyles.PopupEx;
					break;
					
				case WindowStyle.Borderless:
					dwStyle = WindowDWStyles.Borderless;
					dwExStyle = WindowDWStyles.BorderlessEx;
					break;
					
				case WindowStyle.Dialog:
				default:
					dwStyle = WindowDWStyles.Dialog;
					dwExStyle = WindowDWStyles.DialogEx;
					break;
			}
			
			// multiple monitors support

			vec2!int setpos = location();
			MONITORINFOEXA mi;
			mi.cbSize = MONITORINFOEXA.sizeof;
			
			HMONITOR hMonitor = *cast(HMONITOR*)display().__handle;
			GetMonitorInfoA(hMonitor, &mi);
			
			if (windowStyle == WindowStyle.Fullscreen) {
				rect = mi.rcMonitor;
				
				setpos.x = rect.left;
				setpos.y = rect.top;
			}
			
			setpos.x -= rect.left;
			setpos.y -= rect.top;
			
			if (windowStyle != WindowStyle.Fullscreen) {
				AdjustWindowRectEx(&rect, dwStyle, false, dwExStyle);
			}
			
			// multiple monitors support
			
			SetWindowLongW(hwnd, GWL_STYLE, dwStyle);
			SetWindowLongW(hwnd, GWL_EXSTYLE, dwExStyle);
			SetWindowPos(hwnd, null, setpos.x, setpos.y, rect.right - rect.left, rect.bottom - rect.top, SWP_NOCOPYBITS | SWP_NOZORDER | SWP_NOOWNERZORDER);
			
			if (windowStyle == WindowStyle.Fullscreen) {
				SetWindowPos(hwnd, cast(HWND)0 /*HWND_TOP*/, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER);
			}
		}
		
		WindowStyle getStyle() {
			return windowStyle;
		}

		// Implementation stuff

		package(cf.spew) {
			bool impl_cursorset(LPARAM lParam) nothrow {
				if (LOWORD(lParam) == HTCLIENT && cursorStyle != WindowCursorStyle.Underterminate) {
					SetCursor(hCursor);
					return true;
				} else
					return false;
			}

			void impl_callOnClose() nothrow {
				try {
					onCloseDel();
				} catch (Exception e) {}
			}
		}
	}
}