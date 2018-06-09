/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.window_creator;
import cf.spew.implementation.instance;
import cf.spew.ui;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.context.features.custom;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, make, dispose;

abstract class WindowCreatorImpl : IWindowCreator, Have_CustomCtx { 
	package(cf.spew) {
		shared(UIInstance) uiInstance;
		
		vec2!ushort size_ = vec2!ushort(cast(short)800, cast(short)600);
		vec2!short location_;
		IDisplay display_;
		IWindow parentWindow_;
		IAllocator alloc;
		
		ImageStorage!RGBA8 icon;
		
		WindowCursorStyle cursorStyle = WindowCursorStyle.Standard;
		ImageStorage!RGBA8 cursorIcon;
		vec2!ushort customIconHotspot;

		WindowStyle windowStyle = WindowStyle.Dialog;
		
		bool useVRAMContext, vramWithAlpha;
		bool shouldAutoLockCursor;

		bool useOGLContext;
		OpenGLVersion oglVersion;
		OpenGL_Context_Callbacks* oglCallbacks;

		managed!ICustomContext customContext;

		bool shouldAssignMenu;
	}

	this(shared(UIInstance) uiInstance, IAllocator alloc) {
		this.alloc = alloc;
		this.uiInstance = uiInstance;
		
		useVRAMContext = true;
	}

	~this() {
		if (cursorIcon !is null)
			alloc.dispose(cursorIcon);
	}

	@property {
		void size(vec2!ushort v) { size_ = v; }
		void location(vec2!short v) { location_ = v; }
		void display(IDisplay v) { display_ = v; }
		void allocator(IAllocator v) { alloc = v; }
	}

	void assignCustomContext(managed!ICustomContext ctx) {
		customContext = ctx;
		useOGLContext = false;
		useVRAMContext = false;
	}

	void parentWindow(IWindow window) {
		this.parentWindow_ = window;
	}

	managed!IRenderPoint create() {
		return cast(managed!IRenderPoint)createWindow();
	}
}

version(Windows) {
	class WindowCreatorImpl_WinAPI : WindowCreatorImpl,
		Have_Icon, Have_Cursor, Have_Style,
		Have_VRamCtx, Have_OGLCtx, Have_Window_MenuCreator,
		Feature_Icon, Feature_Cursor, Feature_Style {

		import cf.spew.implementation.windowing.misc;
		import core.sys.windows.windows;
		import cf.spew.implementation.windowing.window;
		import cf.spew.implementation.windowing.contexts.vram;
		import cf.spew.implementation.windowing.contexts.opengl;
		import cf.spew.implementation.windowing.contexts.custom;

		import core.sys.windows.windows : DWORD, RECT, HWND, HMENU, WNDCLASSEXW, HINSTANCE,
			GetClassInfoExW, IDC_ARROW, IMAGE_CURSOR, LR_DEFAULTSIZE, LR_SHARED, RegisterClassExW,
			GetModuleHandleW, CS_OWNDC, LoadImageW, MONITORINFOEXA, HMONITOR, GetMonitorInfoA,
			AdjustWindowRectEx, CreateWindowExW, SetWindowLongPtrW, GWLP_USERDATA, InvalidateRgn,
			CreateMenu;
		import cf.spew.event_loop.wells.winapi;

		this(shared(UIInstance) uiInstance, IAllocator alloc) {
			super(uiInstance, alloc);
		}

		managed!IWindow createWindow() {
			WindowImpl_WinAPI ret = null;
			IContext context = null;

			HWND hwnd;
			HMENU hMenu = null;
			WNDCLASSEXW wndClass;
			HINSTANCE hInstance;

			RECT rect;
			DWORD dwStyle, dwExStyle;
			vec2!short setpos = location_;

			auto primaryDisplay = uiInstance.primaryDisplay;

			// window class

			wndClass.cbSize = WNDCLASSEXW.sizeof;
			hInstance = GetModuleHandleW(null);

			if (shouldAssignMenu) {
				hMenu = CreateMenu();
			}
			
			if (GetClassInfoExW(hInstance, cast(wchar*)ClassNameW.ptr, &wndClass) == 0) {
				wndClass.cbSize = WNDCLASSEXW.sizeof;
				wndClass.hInstance = hInstance;
				wndClass.lpszClassName = cast(wchar*)ClassNameW.ptr;
				wndClass.hCursor = LoadImageW(null, cast(wchar*)IDC_ARROW, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
				wndClass.style = CS_OWNDC/+ | CS_HREDRAW | CS_VREDRAW+/; // causes flickering
				wndClass.lpfnWndProc = &callbackWindowHandler;

				RegisterClassExW(&wndClass);
			}

			// window style

			rect.right = size_.x;
			rect.bottom = size_.y;

			switch(windowStyle) {
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

			// multiple monitor support

			MONITORINFOEXA mi;
			mi.cbSize = MONITORINFOEXA.sizeof;
			
			HMONITOR hMonitor;
			if (display_ is null)
				hMonitor = *cast(HMONITOR*)primaryDisplay.__handle;
			else
				hMonitor = *cast(HMONITOR*)display_.__handle;
			GetMonitorInfoA(hMonitor, &mi);
			
			if (windowStyle == WindowStyle.Fullscreen) {
				rect = mi.rcMonitor;
				
				setpos.x = cast(short)rect.left;
				setpos.y = cast(short)rect.top;
			}
			
			setpos.x -= rect.left;
			setpos.y -= rect.top;
			
			if (windowStyle != WindowStyle.Fullscreen) {
				AdjustWindowRectEx(&rect, dwStyle, false, dwExStyle);
			}

			// the window creation

			if (this.parentWindow_ !is null) {
				hwnd = CreateWindowExW(
					dwExStyle,
					cast(wchar*)ClassNameW.ptr,
					null,
					dwStyle,
					setpos.x, setpos.y,
					rect.right - rect.left, rect.bottom - rect.top,
					cast(HWND)this.parentWindow_.__handle,
					hMenu,
					hInstance,
					null);
			}

			if (hwnd is null) {
				hwnd = CreateWindowExW(
					dwExStyle,
					cast(wchar*)ClassNameW.ptr,
					null,
					dwStyle,
					setpos.x, setpos.y,
					rect.right - rect.left, rect.bottom - rect.top,
					null,
					hMenu,
					hInstance,
					null);
			}

			assert(hwnd !is null, "Failed to create Window");

			if (useVRAMContext) {
				context = alloc.make!VRAMContextImpl_WinAPI(hwnd, vramWithAlpha, alloc);
			} else if (useOGLContext) {
				context = alloc.make!OpenGLContextImpl_WinAPI(hwnd, oglVersion, oglCallbacks);
			} else if (customContext !is null) {
				context = alloc.make!CustomContext(customContext);
			}
			
			ret = alloc.make!WindowImpl_WinAPI(hwnd, context, alloc, uiInstance, hMenu, true);
			ret.impl_callbacks_struct.modifySetCursor = &ret.impl_cursorset;
			ret.impl_callbacks_struct.onDestroy = &ret.impl_callOnClose;
			SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(size_t)&ret.impl_callbacks_struct);

			if (customContext !is null)
				(cast(CustomContext)context).init(ret);

			if (icon !is null)
				ret.setIcon(icon);

			if (cursorStyle == WindowCursorStyle.Custom)
				ret.setCustomCursor(cursorIcon, customIconHotspot);
			else
				ret.setCursor(cursorStyle);

			if (shouldAutoLockCursor)
				ret.lockCursorToWindow;

			// done

			InvalidateRgn(hwnd, null, true);
			return managed!IWindow(ret, managers(), alloc);
		}

		Feature_Icon __getFeatureIcon() {
			return this;
		}
		
		Feature_Cursor __getFeatureCursor() {
			return this;
		}
		
		@property {
			ImageStorage!RGBA8 getIcon() { return icon; }
			void setIcon(ImageStorage!RGBA8 v) { icon = v; }
		}
		
		void setCursor(WindowCursorStyle v) { cursorStyle = v; }
		WindowCursorStyle getCursor() { return cursorStyle; }
		
		void setCustomCursor(scope ImageStorage!RGBA8 v, vec2!ushort v2) {
			import devisualization.image.storage.base : ImageStorageHorizontal;
		    import devisualization.image.interfaces : imageObjectFrom;

			if (cursorIcon !is null)
				alloc.dispose(cursorIcon);

			cursorStyle = WindowCursorStyle.Custom;
			cursorIcon = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(v, alloc);
			customIconHotspot = v2;
		}
		
	    ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
		    import devisualization.image.storage.base : ImageStorageHorizontal;
		    import devisualization.image.interfaces : imageObjectFrom;
    	    return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(cursorIcon, alloc);
	    }

		bool lockCursorToWindow() {
			shouldAutoLockCursor = true;
			return true;
		}

		void unlockCursorFromWindow() {
			shouldAutoLockCursor = false;
		}

		Feature_Style __getFeatureStyle() {
			return this;
		}
		
		void setStyle(WindowStyle style) {
			windowStyle = style;
		}
		
		WindowStyle getStyle() {
			return windowStyle;
		}
		
		void assignVRamContext(bool withAlpha=false) {
			useVRAMContext = true;
			useOGLContext = false;
			vramWithAlpha = withAlpha;
		}

		void assignOpenGLContext(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
			useOGLContext = true;
			useVRAMContext = false;

			oglVersion = version_;
			oglCallbacks = callbacks;
		}

		void assignMenu() {
			this.shouldAssignMenu = true;
		}
	}
}

class WindowCreatorImpl_X11 : WindowCreatorImpl,
	Have_Icon, Have_Cursor, Have_Style,
	Have_VRamCtx, Have_OGLCtx,
	Feature_Icon, Feature_Cursor, Feature_Style {

	import cf.spew.implementation.windowing.misc;
	import core.sys.windows.windows;
	import cf.spew.implementation.windowing.window;
	import cf.spew.implementation.windowing.display;
	import cf.spew.implementation.windowing.contexts.vram;
	import cf.spew.implementation.windowing.contexts.opengl;
	import cf.spew.implementation.windowing.contexts.custom;

	import cf.spew.event_loop.wells.x11;
	import devisualization.bindings.x11;

	this(shared(UIInstance) uiInstance, IAllocator alloc) {
		super(uiInstance, alloc);
	}

	managed!IWindow createWindow() {
		WindowImpl_X11 ret;
		IContext context;

		int screenNum = x11.XDefaultScreen(x11Display());
		Window parentWindow;

		// get parent window

		Window* parentId;
		if ((cast(WindowImpl_X11)parentWindow_) !is null && parentWindow_ !is null)
			parentId = cast(Window*)parentWindow_.__handle;
		if (parentId is null)
			parentWindow = x11.XRootWindow(x11Display(), screenNum);
		else
			parentWindow = *parentId;

		// where are we putting the window?

		int actualX, actualY;
		uint actualWidth, actualHeight;

		actualX = location_.x;
		actualY = location_.y;
		actualWidth = size_.x;
		actualHeight = size_.y;

		if (windowStyle == WindowStyle.Fullscreen) {
			if (display_ !is null) {
				if (DisplayImpl_X11 display2 = cast(DisplayImpl_X11)display_) {
			        actualX = location_.x;
			        actualY = location_.y;
			        actualWidth = size_.x;
			        actualHeight = size_.y;
				}
			}
		} else {
			if (display_ !is null) {
				if (DisplayImpl_X11 display2 = cast(DisplayImpl_X11)display_) {
					actualX += display2.x;
					actualY += display2.y;

					if (actualWidth > display2.width)
						actualWidth = display2.width;
					if (actualHeight > display2.height)
						actualHeight = display2.height;
				}
			}
		}

        Window whandle;

        if (useOGLContext) {
            context = alloc.make!OpenGLContextImpl_X11(oglVersion, oglCallbacks);

            XVisualInfo* visualInfo = cast(XVisualInfo*)(cast(OpenGLContextImpl_X11)context).getPlatformData(this, 0);
            XSetWindowAttributes swa;
            Colormap cmap;

            cmap = x11.XCreateColormap(x11Display(), x11.XRootWindow(x11Display(), visualInfo.screen),
                                        visualInfo.visual, AllocNone);
            swa.colormap = cmap;
            swa.background_pixmap = None;
            swa.border_pixel = 0;

            whandle = x11.XCreateWindow(x11Display(), parentWindow,
                actualX, actualY, actualWidth, actualHeight, 0, visualInfo.depth, InputOutput,
                visualInfo.visual, CWBorderPixel|CWColormap, &swa);
            (cast(OpenGLContextImpl_X11)context).setPlatformData(this, 0, &whandle);
        } else {
            whandle = x11.XCreateSimpleWindow(x11Display(), parentWindow,
                actualX, actualY, actualWidth, actualHeight, 0, 0,
                x11.XWhitePixel(x11Display(), screenNum));
        }

		assert(whandle != 0);

        if (x11.XSetWMProtocols !is null) {
            Atom closeAtom = x11Atoms().WM_DELETE_WINDOW;
            if (closeAtom != 0) {
                x11.XSetWMProtocols(x11Display(), whandle, &closeAtom, 1);
            }
        }

		if (useVRAMContext) {
			context = alloc.make!VRAMContextImpl_X11(whandle, vramWithAlpha, alloc);
		} else if (customContext !is null) {
			context = alloc.make!CustomContext(customContext);
		}

		ret = alloc.make!WindowImpl_X11(whandle, context, alloc, uiInstance, true);

		if (customContext !is null)
			(cast(CustomContext)context).init(ret);

		if (icon !is null)
			ret.setIcon(icon);

		if (cursorStyle == WindowCursorStyle.Custom)
			ret.setCustomCursor(cursorIcon, customIconHotspot);
		else
			ret.setCursor(cursorStyle);

		if (shouldAutoLockCursor)
			ret.lockCursorToWindow;

        if (ret.__getFeatureStyle !is null)
		    ret.setStyle(windowStyle);

        ret.eventMasks = ExposureMask | StructureNotifyMask | FocusChangeMask |
                KeyReleaseMask | KeyPressMask | ButtonReleaseMask | ButtonPressMask | PointerMotionMask;
        x11.XSelectInput(x11Display(), whandle, ret.eventMasks);
        x11.XFlush(x11Display());

		return managed!IWindow(ret, managers(), alloc);
	}

	Feature_Icon __getFeatureIcon() {
		return this;
	}

	Feature_Cursor __getFeatureCursor() {
		return this;
	}

	@property {
		ImageStorage!RGBA8 getIcon() { return icon; }
		void setIcon(ImageStorage!RGBA8 v) { icon = v; }
	}

	void setCursor(WindowCursorStyle v) { cursorStyle = v; }
	WindowCursorStyle getCursor() { return cursorStyle; }

	void setCustomCursor(scope ImageStorage!RGBA8 v, vec2!ushort v2) {
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObjectFrom;

		if (cursorIcon !is null)
			alloc.dispose(cursorIcon);

		cursorStyle = WindowCursorStyle.Custom;
		cursorIcon = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(v, alloc);
		customIconHotspot = v2;
	}

	ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObjectFrom;
    	return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(cursorIcon, alloc);
	}

	bool lockCursorToWindow() {
		shouldAutoLockCursor = true;
		return true;
	}

	void unlockCursorFromWindow() {
		shouldAutoLockCursor = false;
	}

	Feature_Style __getFeatureStyle() {
		return this;
	}

	void setStyle(WindowStyle style) {
		windowStyle = style;
	}

	WindowStyle getStyle() {
		return windowStyle;
	}

	void assignVRamContext(bool withAlpha=false) {
		useVRAMContext = true;
		useOGLContext = false;
		vramWithAlpha = withAlpha;
	}

	void assignOpenGLContext(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
		useOGLContext = true;
		useVRAMContext = false;

		oglVersion = version_;
		oglCallbacks = callbacks;
	}
}
