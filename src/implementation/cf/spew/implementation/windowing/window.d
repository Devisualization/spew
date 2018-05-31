/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.window;
import cf.spew.implementation.windowing.misc;
import cf.spew.implementation.instance;
import cf.spew.implementation.windowing.display;
import cf.spew.implementation.windowing.menu;
import cf.spew.ui;
import cf.spew.events.windowing;
import stdx.allocator : IAllocator, make, makeArray, dispose;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8, RGB8;

abstract class WindowImpl : IWindow, IWindowEvents {
	package(cf.spew.implementation) {
		shared(UIInstance) instance;
		IAllocator alloc;
		IContext context_;

		bool ownedByProcess;

		EventOnCursorMoveDel onCursorMoveDel;
		EventOnCursorActionDel onCursorActionDel, onCursorActionEndDel;
		EventOnScrollDel onScrollDel;
		EventOnKeyDel onKeyEntryDel, onKeyPressDel, onKeyReleaseDel;
		EventOnSizeChangeDel onSizeChangeDel;
		EventOnMoveDel onMoveDel;

		EvenOnFileDragDel onFileDragStartDel, onFileDragStopDel;
		EventOnFileDropDel onFileDropDel;
		EventOnFileDraggingDel onFileDraggingDel;

		EventOnForcedDrawDel onDrawDel;
		EventOnCloseDel onCloseDel;
		EventOnRequestCloseDel onRequestCloseDel;
	}
	
	this(shared(UIInstance) instance, bool processOwns) {
		this.instance = instance;
		this.ownedByProcess = processOwns;

		if (processOwns)
			instance.windowToIdMapper[__handle] = cast(shared)this;
	}

	~this() {
		if (ownedByProcess)
			instance.windowToIdMapper.remove(__handle);
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

		void onFileDragStart(EvenOnFileDragDel del) { onFileDragStartDel = del; }
		void onFileDragStopped(EvenOnFileDragDel del) { onFileDragStopDel = del; }
		void onFileDrop(EventOnFileDropDel del) { onFileDropDel = del; }
		void onFileDragging(EventOnFileDraggingDel del) { onFileDraggingDel = del; }

		void onMove(EventOnMoveDel del) { onMoveDel = del; }
		void onRequestClose(EventOnRequestCloseDel del) { onRequestCloseDel = del; }
		void onKeyPress(EventOnKeyDel del) { onKeyPressDel = del; }
		void onKeyRelease(EventOnKeyDel del) { onKeyReleaseDel = del; }
	}
}

version(Windows) {
	import core.sys.windows.oleidl : IDropTarget, LPDATAOBJECT;

	final class WinAPI_DropTarget : IDropTarget {
		import core.sys.windows.windows : HRESULT, IID, DWORD, POINTL, PDWORD, IID_IUnknown, IID_IDropTarget,
			IUnknown, S_OK, E_NOINTERFACE, ULONG, DROPEFFECT;
		import core.atomic : atomicLoad, atomicOp;

		shared(long) count;
		WindowImpl_WinAPI window;
		IAllocator alloc;

		this(WindowImpl_WinAPI window, IAllocator alloc) {
			this.window = window;
			this.alloc = alloc;
			window.comDropTargetLoc = &window;
		}

	extern(System):

		HRESULT QueryInterface(const(IID)* riid, void** ppv) {
			import std.stdio;
			writeln("QueryInterface");stdout.flush;

			if (*riid == IID_IDropTarget) { 
				*ppv = cast(void*)cast(IDropTarget)this;
				AddRef();
				return S_OK;
			} else if (*riid == IID_IUnknown) {
				*ppv = cast(void*)cast(IUnknown)this;
				AddRef();
				return S_OK;
			} else {
				*ppv = null;
				return E_NOINTERFACE;
			}
		}

		ULONG AddRef() {
			atomicOp!"+="(count, 1);
			return cast(ULONG)atomicLoad(count);
		}

		ULONG Release() {
			atomicOp!"-="(count, 1);
			auto ret = atomicLoad(count);

			if (ret == 0)
				alloc.dispose(this);
			return cast(ULONG)ret;
		}

		HRESULT DragEnter(LPDATAOBJECT pDataObj,DWORD grfKeyState,POINTL pt,PDWORD pdwEffect) {
			if (window !is null) {
				try {
					if (window.onFileDragStartDel !is null)
						window.onFileDragStartDel();
				} catch(Exception e) {
					// don't let the exceptions propergate!
					// could cause some real issues in another process...
				}
			}
			*pdwEffect = DROPEFFECT.DROPEFFECT_COPY;
			return S_OK;
		}

		HRESULT DragOver(DWORD grfKeyState,POINTL pt,PDWORD pdwEffect) {
			*pdwEffect = DROPEFFECT.DROPEFFECT_NONE;

			if (window !is null) {
				try {
					if (window.onFileDraggingDel !is null && window.onFileDraggingDel(pt.x, pt.y))
						*pdwEffect = DROPEFFECT.DROPEFFECT_COPY;
				} catch(Exception e) {
					// don't let the exceptions propergate!
					// could cause some real issues in another process...
				}
			}
			return S_OK;
		}

		HRESULT DragLeave() {
			if (window !is null) {
				try {
					if (window.onFileDragStopDel !is null)
						window.onFileDragStopDel();
				} catch(Exception e) {
					// don't let the exceptions propergate!
					// could cause some real issues in another process...
				}
			}

			return S_OK;
		}

		HRESULT Drop(LPDATAOBJECT,DWORD,POINTL,PDWORD) {
			// We do nothing here.
			// The COM interface method is quite complex.
			// But since WM_FILES event works quite ok, we'll be doing that instead.
			// Unfortunately we need this class for the other events.
			return S_OK;
		}
	}

	final class WindowImpl_WinAPI : WindowImpl,
		Feature_Window_ScreenShot, Feature_Icon, Feature_Window_Menu, Feature_Cursor, Feature_Style,
		Have_Window_ScreenShot, Have_Icon, Have_Window_Menu, Have_Cursor, Have_Style {

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
			bool isClosed;

			// this is very high up in field orders, that way this classes data will be in cache when accessed
			EventLoopAlterationCallbacks impl_callbacks_struct;

			List!Window_MenuItem menuItems = void;
			uint menuItemsCount;
			Map!(size_t, Window_MenuItem) menuItemsIds = void;
			Map!(size_t, Window_MenuCallback) menuCallbacks = void;
			
			WindowStyle windowStyle;
			WindowImpl_WinAPI* comDropTargetLoc;
			
			WindowCursorStyle cursorStyle;
			ImageStorage!RGBA8 customCursor;
		}

		@disable this(shared(UIInstance) instance);

		this(HWND hwnd, IContext context, IAllocator alloc, shared(UIInstance) instance, HMENU hMenu=null, bool processOwns=false) {
			this.hwnd = hwnd;
			this.alloc = alloc;
			this.context_ = context;
			this.hMenu = hMenu;

			super(instance, processOwns);

			menuItems = List!Window_MenuItem(alloc);
			menuItemsIds = Map!(size_t, Window_MenuItem)(alloc);
			menuCallbacks = Map!(size_t, Window_MenuCallback)(alloc);
			menuItemsCount = 9000;

			if (processOwns)
				hCursor = LoadImageW(null, cast(wchar*)IDC_APPSTARTING, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
			else
				cursorStyle = WindowCursorStyle.Indeterminate;

			DragAcceptFiles(hwnd, false);
		}
		
		~this() {
			if (menuItems.length > 0) {
				foreach(item; menuItems) {
					item.remove();
				}
			}

			if (context_ !is null)
				alloc.dispose(context_);
			close();
		}

		@property {
			vec2!uint size() {
				if (!visible || isClosed)
					return vec2!uint(0, 0);
				
				RECT rect;
				GetClientRect(hwnd, &rect);
				
				if (rect.right < 0 || rect.bottom < 0)
					return vec2!uint(0, 0);
				
				return vec2!uint(rect.right, rect.bottom);
			}

			managed!IDisplay display() {
				import std.typecons : tuple;

				if (!visible || isClosed)
					return managed!IDisplay.init;

				HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONULL);
				if (monitor is null)
					return (managed!IDisplay).init;
				else
					return cast(managed!IDisplay)managed!DisplayImpl_WinAPI(managers(), tuple(monitor, alloc, instance), alloc);
			}

			bool renderable() { return !isClosed && IsWindowVisible(hwnd) == 1; }

			size_t __handle() { return cast(size_t)hwnd; }

			override void onFileDrop(EventOnFileDropDel del) {
				if (isClosed) return;
				super.onFileDrop(del);

				if (del !is null) {
					RegisterDragDrop(hwnd, alloc.make!WinAPI_DropTarget(this, alloc));
					DragAcceptFiles(hwnd, true);
				} else {
					if (comDropTargetLoc !is null) {
						*comDropTargetLoc = null;
						comDropTargetLoc = null;
					}
					
					RevokeDragDrop(hwnd);
					DragAcceptFiles(hwnd, false);
				}
			}
		}

		void close() {
			if (isClosed) return;
			// specifically requested to close!

			isClosed = true;
			onFileDrop(null);
			DestroyWindow(hwnd);
		}

		@property {
			managed!dstring title() {
				if (isClosed)
					return managed!dstring.init;

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
				return managed!dstring(cast(dstring)buffer2, managers(), alloc);
			}
			
			void title(string text) { setTitle(text); }
			void title(wstring text) { setTitle(text); }
			void title(dstring text) { setTitle(text); }
			
			void setTitle(String)(String text) if (isSomeString!String) {
				if (isClosed) return;

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
				if (!visible || isClosed) return;
				SetWindowPos(hwnd, null, point.x, point.y, 0, 0, SWP_NOSIZE);
			}

			vec2!int location() {
				if (!visible || isClosed)
					return vec2!int.init;

				RECT rect;
				GetWindowRect(hwnd, &rect);
				return vec2!int(rect.left, rect.top);
			}

			void size(vec2!uint point) {
				if (!visible || isClosed)
					return;

				RECT rect;
				rect.top = point.x;
				rect.bottom = point.y;
				
				assert(AdjustWindowRectEx(&rect, GetWindowLongA(hwnd, GWL_STYLE), GetMenu(hwnd) !is null, GetWindowLongA(hwnd, GWL_EXSTYLE)));
				SetWindowPos(hwnd, null, 0, 0, rect.right, rect.bottom, SWP_NOMOVE);
			}
		}

		void hide() {
			if (isClosed) return;
			ShowWindow(hwnd, SW_HIDE);
		}
		
		void show() {
			if (isClosed) return;

			ShowWindow(hwnd, SW_SHOW);
			UpdateWindow(hwnd);
		}

		Feature_Window_ScreenShot __getFeatureScreenShot() {
			if (isClosed) return null;
			else return this;
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
			if (isClosed) return null;
			else return this;
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
		
		Feature_Window_Menu __getFeatureMenu() {
			if (hMenu is null || isClosed)
				return null;
			else
				return this;
		}
		
		Window_MenuItem addItem() {
			auto ret = cast(Window_MenuItem)alloc.make!MenuItemImpl_WinAPI(this, hMenu, null);
			
			menuItems ~= ret;
			return ret;
		}
		
		@property managed!(Window_MenuItem[]) items() {
			auto ret = menuItems.opSlice();
			return cast(managed!(Window_MenuItem[]))ret;
		}
		
		Feature_Cursor __getFeatureCursor() {
			return this;
		}
		
		void setCursor(WindowCursorStyle style) {
			if (isClosed) return;
			assert(cursorStyle != WindowCursorStyle.Indeterminate);
			
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
					case WindowCursorStyle.ResizeCornerTopLeft:
					case WindowCursorStyle.ResizeCornerBottomRight:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENESW, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeCornerTopRight:
					case WindowCursorStyle.ResizeCornerBottomLeft:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENWSE, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeLeftHorizontal:
					case WindowCursorStyle.ResizeRightHorizontal:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZEWE, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.ResizeTopVertical:
					case WindowCursorStyle.ResizeBottomVertical:
						hCursor = LoadImageW(null, cast(wchar*)IDC_SIZENS, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
						break;
					case WindowCursorStyle.TextEdit:
						hCursor = LoadImageW(null, cast(wchar*)IDC_IBEAM, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
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
		
		void setCustomCursor(scope ImageStorage!RGBA8 image, vec2!ushort hotspot) {
			import devisualization.image.storage.base : ImageStorageHorizontal;
			import devisualization.image.interfaces : imageObjectFrom;
			
			assert(cursorStyle != WindowCursorStyle.Indeterminate);
			
			// The comments here specify the preferred way to do this.
			// Unfortunately at the time of writing, it is not possible to
			//  use devisualization.image for resizing.
			
			setCursor(WindowCursorStyle.Custom);
			
			HDC hFrom = GetDC(null);
			HDC hMemoryDC = CreateCompatibleDC(hFrom);
			
			// duplicate image, store
			customCursor = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(image, alloc);
			
			// customCursor must be a set size, as defined by:
			vec2!size_t toSize = vec2!size_t(GetSystemMetrics(SM_CXCURSOR), GetSystemMetrics(SM_CYCURSOR));
			hotspot.x *= toSize.x > image.width ? (toSize.x / cast(float)image.width) : (image.width / cast(float)toSize.x);
			hotspot.y *= toSize.y > image.height ? (toSize.y / cast(float)image.height) : (image.height / cast(float)toSize.y);

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
			
			hCursor = CreateCursor(null, cast(DWORD)hotspotx, cast(DWORD)hotspoty, cast(int)toSize.x, cast(int)toSize.y, ii.hbmColor, ii.hbmMask);
			
			DeleteObject(hBitmap);
			DeleteObject(hBitmap2);
			DeleteDC(hMemoryDC);
			ReleaseDC(null, hFrom);
		}
		
		ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
			return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(customCursor, alloc);
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
			if (isClosed) return null;
			else return this;
		}
		
		void setStyle(WindowStyle style) {
			windowStyle = style;
			
			RECT rect;
			DWORD dwStyle, dwExStyle;
			
			switch(style) {
				case WindowStyle.NoDecorations:
					dwStyle = WindowDWStyles.NoDecorations;
					dwExStyle = WindowDWStyles.NoDecorations;
					break;

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
			
			HMONITOR hMonitor = cast(HMONITOR)display().__handle;
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
				if (LOWORD(lParam) == HTCLIENT && cursorStyle != WindowCursorStyle.Indeterminate) {
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

final class WindowImpl_X11 : WindowImpl,
		Feature_Window_ScreenShot, Feature_Icon, Feature_Cursor, Feature_Style,
		Have_Window_ScreenShot, Have_Icon, Have_Cursor, Have_Style {
	import devisualization.bindings.x11;
	import cf.spew.event_loop.wells.x11;
    import std.traits : isSomeString;
	import std.utf : codeLength, byDchar, byChar;

	@disable this(shared(UIInstance) instance);

	bool isClosed, supportsXDND;
	Window whandle;
    XIC xic;

    Atom xdndToBeRequested;
    Window xdndSourceWindow;

    uint eventMasks;
    WindowStyle wstyle;

	Cursor currentCursor = None;
	WindowCursorStyle cursorStyle;
	ImageStorage!RGBA8 customCursor;
	XcursorImage* customCursorImage;

    int lastX, lastY;
    int lastWidth, lastHeight;

	this(Window handle, IContext context, IAllocator alloc, shared(UIInstance) uiInstance, bool processOwns=false) {
		this.whandle = handle;
		this.alloc = alloc;
		this.context_ = context;

		super(uiInstance, processOwns);

        xic = x11.XCreateIC(x11XIM(),
                        XNInputStyle.ptr, XIMPreeditNothing | XIMStatusNothing,
                        XNClientWindow.ptr, whandle,
                        XNFocusWindow.ptr, whandle, 0);

        if (x11Atoms().XdndAware != None) {
            supportsXDND  = true;
            Atom version_ = 5;
            x11.XChangeProperty(x11Display(), whandle, x11Atoms().XdndAware, x11Atoms().XA_ATOM, 32, PropModeReplace, cast(ubyte*)&version_, 1);
        }
	}

	~this() {
		if (context_ !is null)
			alloc.dispose(context_);
		close();
	}

	@property {
		vec2!uint size() {
			if (!visible || isClosed) return vec2!uint.init;
			auto att = x11WindowAttributes(whandle);
			return vec2!uint(att.width, att.height);
		}

		managed!IDisplay display() {
			import std.algorithm : max, min;
			IDisplay theDisplay;
			int numMonitors;
			XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), whandle, true, &numMonitors);

			if (numMonitors == -1)
				return managed!(IDisplay).init;

			XRRMonitorInfo theMonitor;
			auto att = x11WindowAttributes(whandle);
			int x2 = att.x + att.width, y2 = att.y + att.height;
			int lastOverlap;

			foreach(i; 0 .. numMonitors) {
				int x1 = monitors[i].x + monitors[i].width, y1 = monitors[i].x + monitors[i].y;
				int xOverlap = max(0, min(x2, x1) - max(att.x, monitors[i].x));
				int yOverlap = max(0, min(y2, y1) - max(att.y, monitors[i].y));
				int overlap = xOverlap * yOverlap;

				if (overlap > lastOverlap) {
					lastOverlap = overlap;
					theMonitor = monitors[i];
				}
			}

			x11.XRRFreeMonitors(monitors);
			return managed!IDisplay(alloc.make!DisplayImpl_X11(att.screen, &theMonitor, alloc, instance), managers(ReferenceCountedManager()), alloc);
		}

		bool renderable() {
			if (isClosed) return false;
			auto att = x11WindowAttributes(whandle);
			return (att.map_state & IsViewable) == IsViewable;
		}

		size_t __handle() { return cast(size_t)whandle; }

		override void onFileDrop(EventOnFileDropDel del) { onFileDropDel = del; }
	}

	void close() {
        if (isClosed) return;

        if (xic !is null) {
            x11.XDestroyIC(xic);
            xic = null;
        }

        hide();
		x11.XDestroyWindow(x11Display(), whandle);

		if (currentCursor != None)
			x11.XFreeCursor(x11Display(), currentCursor);
		if (customCursorImage !is null) // ugh are these needed?
			x11.XcursorImageDestroy(customCursorImage);

		isClosed = true;
        x11.XFlush(x11Display());
	}

	@property {
		managed!dstring title() {
			import core.stdc.string : strlen;

			char* temp;
			char[] buffer = temp[0 .. strlen(temp)];
			x11.XFetchName(x11Display(), whandle, &temp);

			// what is allocated could potentially be _more_ then required
			dchar[] buffer2 = alloc.makeArray!dchar(codeLength!char(buffer));

			size_t i;
			foreach(c; buffer.byDchar) {
				buffer2[i] = c;
				i++;
			}

			alloc.dispose(buffer);
			x11.XFree(temp);
			return managed!dstring(cast(dstring)buffer2, managers(), alloc);
		}

		void title(string text) { setTitle(text); }
		void title(wstring text) { setTitle(text); }
		void title(dstring text) { setTitle(text); }

		void setTitle(String)(String text) if (isSomeString!String) {
			// if this ends in segfaults, switch to malloc and don't free.
			// xlib will free.

			char[] temp = alloc.makeArray!char(codeLength!char(text) + 1);
			temp[$-1] = 0;

			size_t i;
			foreach(c; text.byChar) {
				temp[i] = c;
				i++;
			}

			x11.XStoreName(x11Display(), whandle, temp.ptr);
			alloc.dispose(temp);
		}

		void location(vec2!int point) {
			if (isClosed) return;
			x11.XMoveWindow(x11Display(), whandle, point.x, point.y);
			x11.XFlush(x11Display());
		}

		vec2!int location() {
			if (isClosed) return vec2!int.init;
			auto att = x11WindowAttributes(whandle);
			return vec2!int(att.x, att.y);
		}

		void size(vec2!uint point) {
			if (isClosed) return;
			x11.XResizeWindow(x11Display(), whandle, point.x, point.y);
			x11.XFlush(x11Display());
		}
	}

	void hide() {
		if (isClosed) return;
		x11.XUnmapWindow(x11Display(), whandle);
	}

	void show() {
		if (isClosed) return;
		x11.XMapWindow(x11Display(), whandle);
	}

	Feature_Window_ScreenShot __getFeatureScreenShot() {
		if (isClosed) return null;
		return this;
	}

	ImageStorage!RGB8 screenshot(IAllocator alloc=null) {
		if (isClosed) return null;

		import devisualization.image : ImageStorage;
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObject;
		import std.experimental.color : RGB8, RGBA8;

		if (alloc is null)
			alloc = this.alloc;

		auto theSize = size();
		XImage* complete = x11.XGetImage(x11Display(), cast(Drawable)whandle, 0, 0, theSize.x, theSize.y, AllPlanes, ZPixmap);
		auto storage = imageObject!(ImageStorageHorizontal!RGB8)(theSize.x, theSize.y, alloc);

		foreach(y; 0 .. theSize.y) {
			foreach(x; 0 .. theSize.x) {
				auto pix = x11.XGetPixel(complete, x, y);
				storage[x, y] = RGB8(cast(ubyte)((pix & complete.red_mask) >> 16), cast(ubyte)((pix & complete.green_mask) >> 8), cast(ubyte)(pix & complete.blue_mask));
			}
		}

		x11.XFree(complete);
		return storage;
	}

	Feature_Icon __getFeatureIcon() {
		if (isClosed) return null;
		return this;
	}

	ImageStorage!RGBA8 getIcon() @property {
		import devisualization.image : ImageStorage;
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObject;
		import std.experimental.color : RGB8, RGBA8;

		Atom net_wm_icon = x11Atoms()._NET_WM_ICON;
		Atom cardinal = x11Atoms().CARDINAL;

		X11WindowProperty prop = x11ReadWindowProperty(x11Display(), whandle, net_wm_icon);
		scope(exit) if (prop.data !is null) x11.XFree(prop.data);

		if (prop.format == 32 && prop.type == cardinal && prop.data !is null && prop.numberOfItems > 1) {
			// great same, we can use this!

			uint* source = cast(uint*)prop.data;
			ushort width = cast(ushort)source[0], height = cast(ushort)(source[0] >> 16);

			if ((width*height)+1 != prop.numberOfItems)
				return null;

			auto storage = imageObject!(ImageStorageHorizontal!RGBA8)(width, height, alloc);
			size_t offset=1;

			foreach(y; 0 .. height) {
		        foreach(x; 0 .. width) {
					uint p = source[offset++];
			        storage[x, y] = RGBA8((cast(ubyte)(p >> 16)), (cast(ubyte)(p >> 8)), (cast(ubyte)p), (cast(ubyte)(p >> 24)));
		        }
	        }


			return storage;
		} else
			return null;
	}

	void setIcon(ImageStorage!RGBA8 from) @property {
		import core.stdc.stdlib : malloc;

		assert(from.width <= ushort.max);
		assert(from.height <= ushort.max);

		int numItems = cast(int)(from.width*from.height)+1;
		uint[] imageData = (cast(uint*)malloc(4*numItems))[0 .. numItems];
		size_t offset=1;

		imageData[0] = (cast(ushort)from.height << 16) | cast(ushort)from.width;

		foreach(y; 0 .. from.height) {
			foreach(x; 0 .. from.width) {
				auto p = from[x, y];
				imageData[offset++] = p.b.value | (p.g.value << 8) | (p.r.value << 16) | (p.a.value << 24);
			}
		}

		Atom net_wm_icon = x11Atoms()._NET_WM_ICON;
		Atom cardinal = x11Atoms().CARDINAL;
		x11.XChangeProperty(x11Display(), whandle, net_wm_icon, cardinal, 32, PropModeReplace, cast(ubyte*)imageData.ptr, numItems);
	}

	Feature_Cursor __getFeatureCursor() {
	    if (isClosed) return null;
	    return this;
	}

	void setCursor(WindowCursorStyle style) {
		if (isClosed) return;
		assert(cursorStyle != WindowCursorStyle.Indeterminate);

        // unload systemy stuff
        if (currentCursor != None)
	        x11.XFreeCursor(x11Display(), currentCursor);
		if (customCursorImage !is null) // ugh are these needed?
			x11.XcursorImageDestroy(customCursorImage);

		cursorStyle = style;

		if (style != WindowCursorStyle.Custom) {
			// load up reference to system one

			switch(style) {
				case WindowCursorStyle.Busy:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_watch);
					break;
				case WindowCursorStyle.Hand:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_hand1);
					break;
				case WindowCursorStyle.NoAction:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_X_cursor);
					break;
				case WindowCursorStyle.ResizeCornerTopLeft:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_left_corner);
					break;
				case WindowCursorStyle.ResizeCornerTopRight:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_right_corner);
					break;
				case WindowCursorStyle.ResizeCornerBottomLeft:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_left_corner);
					break;
				case WindowCursorStyle.ResizeCornerBottomRight:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_right_corner);
					break;

				case WindowCursorStyle.ResizeLeftHorizontal:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_left_side);
					break;
				case WindowCursorStyle.ResizeTopVertical:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_side);
					break;
				case WindowCursorStyle.ResizeRightHorizontal:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_right_side);
					break;
				case WindowCursorStyle.ResizeBottomVertical:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_side);
					break;

				case WindowCursorStyle.TextEdit:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_xterm);
					break;

				case WindowCursorStyle.None:
					currentCursor = None;
					break;
				case WindowCursorStyle.Standard:
				default:
					currentCursor = x11.XCreateFontCursor(x11Display(), XC_left_ptr);
					break;
			}
			
			XSetWindowAttributes attr;
			attr.cursor = currentCursor;
			x11.XChangeWindowAttributes(x11Display(), whandle, CWCursor, &attr);
		}
	}

	WindowCursorStyle getCursor() { return cursorStyle; }
	
	void setCustomCursor(scope ImageStorage!RGBA8 image, vec2!ushort hotspot) {
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObjectFrom;

		if (image is null) return;
		assert(cursorStyle != WindowCursorStyle.Indeterminate);

		if (x11.XcursorImageCreate !is null && x11.XcursorImageLoadCursor !is null && x11.XcursorImageDestroy !is null &&
			x11.XcursorSupportsARGB !is null && x11.XcursorSupportsARGB(x11Display()) == XcursorTrue) {

            if (currentCursor != None)
	    		x11.XFreeCursor(x11Display(), currentCursor);
			if (customCursorImage !is null)
				x11.XcursorImageDestroy(customCursorImage);

		    // The comments here specify the preferred way to do this.
		    // Unfortunately at the time of writing, it is not possible to
		    //  use devisualization.image for resizing.

		    setCursor(WindowCursorStyle.Custom);

		    // duplicate image, store
		    customCursor = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(image, alloc);

			customCursorImage = x11.XcursorImageCreate(cast(int)image.width, cast(int)image.height);
			customCursorImage.xhot = hotspot.x;
			customCursorImage.yhot = hotspot.y;

			size_t offset;
			foreach(y; 0 .. image.height) {
			    foreach(x; 0 .. image.width) {
				    auto p = image[x, y];
				    customCursorImage.pixels[offset++] = p.b.value | (p.g.value << 8) | (p.r.value << 16) | (p.a.value << 24);
			    }
		    }

			currentCursor = x11.XcursorImageLoadCursor(x11Display(), customCursorImage);
		}
	}

	ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObjectFrom;
    	return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(customCursor, alloc);
	}

	bool lockCursorToWindow() {
		// if this fails, we'll just have to return false :/
        auto ret = x11.XGrabPointer(x11Display(), whandle, false,
            ~(ExposureMask | KeyPressMask | KeyReleaseMask) & eventMasks, GrabModeAsync, GrabModeAsync, whandle, currentCursor, CurrentTime);
		return ret == GrabSuccess;
	}

	void unlockCursorFromWindow() {
		x11.XUngrabPointer(x11Display(), CurrentTime);
	}

	Feature_Style __getFeatureStyle() { return isClosed ? null : this; }

    void setStyle(WindowStyle style) {
        wstyle = style;

        bool noResize;
        Motif_WMHints motifWmHints;

        Atom windowType = x11Atoms()._NET_WM_WINDOW_TYPE_NORMAL;
        Atom[10] wmAllowedActions, wmState;
        uint wmAllowedActionsCount, wmStateCount;

        switch(style) {
            case WindowStyle.NoDecorations:
                noResize = true;
                motifWmHints = WindowX11Styles.NoDecorations;

                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_STICKY;
                break;

            case WindowStyle.Fullscreen:
                motifWmHints = WindowX11Styles.Fullscreen;

                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_FULLSCREEN;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_ABOVE;

                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_FULLSCREEN;
                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_ABOVE;

                // reset size hints in case already set

                XSizeHints sizeHints;
                sizeHints.flags = PMinSize | PMaxSize;

                sizeHints.min_width = 0;
                sizeHints.max_width = int.max;
                sizeHints.min_height = 0;
                sizeHints.max_height = int.max;

                x11.XSetWMNormalHints(x11Display(), whandle, &sizeHints);
                break;

            case WindowStyle.Popup:
                noResize = true;
                motifWmHints = WindowX11Styles.Popup;
                windowType = x11Atoms()._NET_WM_STATE_MODAL;

                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_ABOVE;

                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_ABOVE;
                break;

            case WindowStyle.Borderless:
                noResize = true;
                motifWmHints = WindowX11Styles.Borderless;
                windowType = x11Atoms()._NET_WM_WINDOW_TYPE_UTILITY;

                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                break;

            case WindowStyle.Dialog:
            default:
                motifWmHints = WindowX11Styles.Dialog;

                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_RESIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MAXIMIZE_HORZ;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MAXIMIZE_VERT;
                break;
        }

        auto currentwAttributes = x11WindowAttributes(whandle);
        lastWidth = currentwAttributes.width;
        lastHeight = currentwAttributes.height;

        // sets WM_NORMAL_HINTS
        if (noResize) {
            XSizeHints sizeHints;
            sizeHints.flags = PMinSize | PMaxSize;

            sizeHints.min_width = lastWidth;
            sizeHints.max_width = lastWidth;
            sizeHints.min_height = lastHeight;
            sizeHints.max_height = lastHeight;

            x11.XSetWMNormalHints(x11Display(), whandle, &sizeHints);
        }

        // first up we /try/ to setup window hints using motif as a fallback
        Atom motifWindowHintsAtom = x11Atoms()._MOTIF_WM_HINTS;
        if (motifWindowHintsAtom != None)
            x11.XChangeProperty(x11Display(), whandle, motifWindowHintsAtom, motifWindowHintsAtom, 32, PropModeReplace, cast(ubyte*)&motifWmHints, 5);

        Atom xaAtom = x11Atoms().XA_ATOM;
        if (xaAtom != None) {
            // apply _NET_WM_ALLOWED_ACTIONS
            Atom wmAllowedActionsAtom = x11Atoms()._NET_WM_ALLOWED_ACTIONS;
            if (wmAllowedActionsAtom != None)
                x11.XChangeProperty(x11Display(), whandle, wmAllowedActionsAtom, xaAtom, 32, PropModeReplace, cast(ubyte*)wmAllowedActions.ptr, wmAllowedActionsCount);

            // apply _NET_WM_STATE
            Atom wmStateAtom = x11Atoms()._NET_WM_STATE;
            if (wmStateAtom != None)
                x11.XChangeProperty(x11Display(), whandle, wmStateAtom, xaAtom, 32, PropModeReplace, cast(ubyte*)wmState.ptr, wmStateCount);
        }

        // full screen requires further special behavior
        // which requires knowledge of the monitor itself
        if (style == WindowStyle.Fullscreen) {
            XEvent xev;
            xev.type = ClientMessage;
            xev.xclient.window = whandle;
            xev.xclient.message_type = x11Atoms()._NET_WM_STATE;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = 1;
            xev.xclient.data.l[1] = x11Atoms()._NET_WM_STATE_FULLSCREEN;
            xev.xclient.data.l[2] = 0;

            x11.XMapWindow(x11Display(), whandle);
            x11.XSendEvent(x11Display(), x11.XDefaultRootWindow(x11Display()), false, SubstructureRedirectMask | SubstructureNotifyMask, &xev);
        }

        x11.XFlush(x11Display());
    }

	WindowStyle getStyle() { return wstyle; }
}
