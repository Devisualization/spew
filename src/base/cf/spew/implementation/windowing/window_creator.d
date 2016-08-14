module cf.spew.implementation.windowing.window_creator;
import cf.spew.implementation.details;
import cf.spew.implementation.platform;

abstract class WindowCreatorImpl : IWindowCreator { 
	package(cf.spew) {
		PlatformImpl platform;
		
		vec2!ushort size_ = vec2!ushort(cast(short)800, cast(short)600);
		vec2!short location_;
		IDisplay display_;
		IAllocator alloc;
		
		ImageStorage!RGBA8 icon;
		
		WindowCursorStyle cursorStyle = WindowCursorStyle.Standard;
		ImageStorage!RGBA8 cursorIcon;
		
		WindowStyle windowStyle = WindowStyle.Dialog;
		
		bool useVRAMContext, vramWithAlpha;
	}

	this(PlatformImpl platform, IAllocator alloc) {
		this.alloc = alloc;
		this.platform = platform;
		
		useVRAMContext = true;
	}

	@property {
		void size(vec2!ushort v) { size_ = v; }
		void location(vec2!short v) { location_ = v; }
		void display(IDisplay v) { display_ = v; }
		void allocator(IAllocator v) { alloc = v; }
	}

	IRenderPoint create() {
		return cast(IRenderPoint)createWindow;
	}
}

version(Windows) {
	class WindowCreatorImpl_WinAPI : WindowCreatorImpl,
		Have_Icon, Have_Cursor, Have_Style, Have_VRamCtx,
		Feature_Icon, Feature_Cursor, Feature_Style {

		import cf.spew.implementation.windowing.window;
		import cf.spew.implementation.contexts.vram;

		import core.sys.windows.windows : DWORD, RECT, HWND, HMENU, WNDCLASSEXW, HINSTANCE,
			GetClassInfoExW, IDC_ARROW, IMAGE_CURSOR, LR_DEFAULTSIZE, LR_SHARED, RegisterClassExW,
			GetModuleHandleW, CS_OWNDC, LoadImageW, MONITORINFOEXA, HMONITOR, GetMonitorInfoA,
			AdjustWindowRectEx, CreateWindowExW, SetWindowLongPtrW, GWLP_USERDATA, InvalidateRgn;

		this(PlatformImpl platform, IAllocator alloc) {
			super(platform, alloc);
		}

		IWindow createWindow() {
			import std.stdio;
			auto primaryDisplay = platform.primaryDisplay;

			RECT rect;
			DWORD dwStyle, dwExStyle;
			vec2!short setpos = location_;

			HWND hwnd;
			HMENU hMenu = null;
			WNDCLASSEXW wndClass;
			HINSTANCE hInstance;

			IContext context = null;
			WindowImpl_WinAPI ret;

			void configure_class() {
				import cf.spew.event_loop.wells.winapi;
				wndClass.cbSize = WNDCLASSEXW.sizeof;
				hInstance = GetModuleHandleW(null);

				if (GetClassInfoExW(hInstance, cast(wchar*)ClassNameW.ptr, &wndClass) == 0) {
					wndClass.cbSize = WNDCLASSEXW.sizeof;
					wndClass.hInstance = hInstance;
					wndClass.lpszClassName = cast(wchar*)ClassNameW.ptr;
					wndClass.hCursor = LoadImageW(null, cast(wchar*)IDC_ARROW, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
					wndClass.style = CS_OWNDC/+ | CS_HREDRAW | CS_VREDRAW+/; // causes flickering
					wndClass.lpfnWndProc = &callbackWindowHandler;
					
					RegisterClassExW(&wndClass);
				}
			}

			void configure_styles() {
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
			}

			// multiple monitor support
			void configure_position() {
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
			}

			void create() {
				hwnd = CreateWindowExW(
					dwExStyle,
					cast(wchar*)ClassNameW.ptr,
					null,
					dwStyle,
					setpos.x, setpos.y,
					rect.right - rect.left, rect.bottom - rect.top,
					null,
					null,
					hInstance,
					null);

				if (useVRAMContext) {
					context = alloc.make!VRAMContextImpl_WinAPI(hwnd, vramWithAlpha, alloc);
				}

				ret = alloc.make!WindowImpl_WinAPI(hwnd, context, alloc, platform, hMenu, true);
				ret.impl_callbacks_struct.modifySetCursor = &ret.impl_cursorset;
				SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(size_t)&ret.impl_callbacks_struct);

				if (icon !is null)
					ret.setIcon(icon);
				
				if (cursorStyle == WindowCursorStyle.Custom)
					ret.setCustomCursor(cursorIcon);
				else
					ret.setCursor(cursorStyle);
			}

			configure_class();
			configure_styles();
			configure_position();
			create();

			InvalidateRgn(hwnd, null, true);
			return ret;
		}

		Feature_Icon __getFeatureIcon() {
			version(Windows) {
				return this;
			} else
				assert(0);
		}
		
		Feature_Cursor __getFeatureCursor() {
			version(Windows)
				return this;
			else
				assert(0);
		}
		
		@property {
			ImageStorage!RGBA8 getIcon() { return icon; }
			void setIcon(ImageStorage!RGBA8 v) { icon = v; }
		}
		
		void setCursor(WindowCursorStyle v) { cursorStyle = v; }
		WindowCursorStyle getCursor() { return cursorStyle; }
		
		void setCustomCursor(ImageStorage!RGBA8 v) {
			cursorStyle = WindowCursorStyle.Custom;
			cursorIcon = v;
		}
		
		ImageStorage!RGBA8 getCursorIcon() { return cursorIcon; }
		
		Feature_Style __getFeatureStyle() {
			version(Windows)
				return this;
			else
				assert(0);
		}
		
		void setStyle(WindowStyle style) {
			windowStyle = style;
		}
		
		WindowStyle getStyle() {
			return windowStyle;
		}
		
		void assignVRamContext(bool withAlpha=false) {
			useVRAMContext = true;
			vramWithAlpha = withAlpha;
		}
	}
}