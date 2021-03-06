module cf.spew.implementation.windowing.window_creator.winapi;
version (Windows):
import cf.spew.implementation.instance.state : uiInstance;
import cf.spew.implementation.windowing.utilities.winapi : ClassNameW,
    WindowDWStyles;
import cf.spew.implementation.windowing.window_creator.base;
import cf.spew.implementation.windowing.window.winapi;
import cf.spew.implementation.windowing.contexts.vram.winapi;
import cf.spew.implementation.windowing.contexts.opengl.winapi;
import cf.spew.implementation.windowing.contexts.custom;
import cf.spew.event_loop.wells.winapi;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features;
import cf.spew.ui.window.features.icon;
import cf.spew.ui.window.features.cursor;
import cf.spew.ui.window.features.menu;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.window.styles;
import devisualization.image : ImageStorage;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, dispose, make;
import std.experimental.color : RGBA8;
import core.sys.windows.windows : DWORD, RECT, HWND, HMENU, WNDCLASSEXW,
    HINSTANCE, GetClassInfoExW, IDC_ARROW, IMAGE_CURSOR, LR_DEFAULTSIZE,
    LR_SHARED, RegisterClassExW, GetModuleHandleW, CS_OWNDC, LoadImageW,
    MONITORINFOEXA, HMONITOR, GetMonitorInfoA, AdjustWindowRectEx,
    CreateWindowExW, SetWindowLongPtrW, GWLP_USERDATA, InvalidateRgn,
    CreateMenu, WS_CLIPCHILDREN;

class WindowCreatorImpl_WinAPI : WindowCreatorImpl, Have_Icon, Have_Cursor, Have_Style, Have_VRamCtx,
    Have_OGLCtx, Have_Window_MenuCreator, Feature_Icon, Feature_Cursor, Feature_Style {

        this(IAllocator alloc) {
            super(alloc);
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
                wndClass.hCursor = LoadImageW(null, cast(wchar*)IDC_ARROW,
                        IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
                wndClass.style = CS_OWNDC /+ | CS_HREDRAW | CS_VREDRAW+/ ; // causes flickering
                wndClass.lpfnWndProc = &callbackWindowHandler;

                RegisterClassExW(&wndClass);
            }

            // window style

            rect.right = size_.x;
            rect.bottom = size_.y;

            switch (windowStyle) {
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

            if (this.parentWindow_ is null)
                dwStyle |= WS_CLIPCHILDREN;

            // multiple monitor support

            MONITORINFOEXA mi;
            mi.cbSize = MONITORINFOEXA.sizeof;

            HMONITOR hMonitor;
            if (display_ is null)
                hMonitor = cast(HMONITOR)primaryDisplay.__handle;
            else
                hMonitor = cast(HMONITOR)display_.__handle;
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
                hwnd = CreateWindowExW(dwExStyle, cast(wchar*)ClassNameW.ptr,
                        null, dwStyle, setpos.x, setpos.y, rect.right - rect.left,
                        rect.bottom - rect.top, cast(HWND)this.parentWindow_.__handle,
                        hMenu, hInstance, null);
            }

            if (hwnd is null) {
                hwnd = CreateWindowExW(dwExStyle, cast(wchar*)ClassNameW.ptr,
                        null, dwStyle, setpos.x, setpos.y, rect.right - rect.left,
                        rect.bottom - rect.top, null, hMenu, hInstance, null);
            }

            assert(hwnd !is null, "Failed to create Window");

            if (useVRAMContext) {
                context = alloc.make!VRAMContextImpl_WinAPI(hwnd, vramWithAlpha, alloc);
            } else if (useOGLContext) {
                context = alloc.make!OpenGLContextImpl_WinAPI(hwnd, oglVersion, oglCallbacks);
            } else if (customContext !is null) {
                context = alloc.make!CustomContext(customContext);
            }

            ret = alloc.make!WindowImpl_WinAPI(hwnd, context, alloc, hMenu, true);
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
            ImageStorage!RGBA8 getIcon() {
                return icon;
            }

            void setIcon(ImageStorage!RGBA8 v) {
                icon = v;
            }
        }

        void setCursor(WindowCursorStyle v) {
            cursorStyle = v;
        }

        WindowCursorStyle getCursor() {
            return cursorStyle;
        }

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

        void assignVRamContext(bool withAlpha = false) {
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
