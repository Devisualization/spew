module cf.spew.implementation.windowing.window.winapi;
version(Windows):
import cf.spew.implementation.instance.state : uiInstance, taskbarTrayWindow, taskbarTrayWindowThread;
import cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.windowing.menu.winapi;
import cf.spew.implementation.windowing.display.winapi : DisplayImpl_WinAPI;
import cf.spew.implementation.windowing.utilities.winapi : screenshotImpl_WinAPI, bitmapToAlphaImage_WinAPI,
    imageToIcon_WinAPI, imageToAlphaBitmap_WinAPI, resizeBitmap_WinAPI, bitmapToIcon_WinAPI, WindowDWStyles;
import cf.spew.ui.window.features.cursor;
import cf.spew.ui.window.features.icon;
import cf.spew.ui.window.features.screenshot;
import cf.spew.ui.window.features.menu;
import cf.spew.ui.window.styles;
import cf.spew.ui.context.defs;
import cf.spew.ui.display.defs;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.events : EventOnFileDropDel;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage, imageObjectFrom, ImageStorageHorizontal;
import stdx.allocator : IAllocator, make, makeArray, dispose;
import std.experimental.color : RGBA8, RGB8;
import core.sys.windows.oleidl : IDropTarget;
import core.sys.windows.objfwd : LPDATAOBJECT;
import core.sys.windows.windows : HRESULT, IID, DWORD, POINTL, PDWORD, IID_IUnknown, IID_IDropTarget,
    IUnknown, S_OK, E_NOINTERFACE, ULONG, DROPEFFECT;
import core.atomic : atomicLoad, atomicOp;

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
        HICON hIcon;
        
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
    
    this(HWND hwnd, IContext context, IAllocator alloc, HMENU hMenu=null, bool processOwns=false) {
        this.hwnd = hwnd;
        this.alloc = alloc;
        this.context_ = context;
        this.hMenu = hMenu;
        
        super(processOwns);
        
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

    override IContext context() {
        if (!visible || isClosed) return null;
        return context_;
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
                return cast(managed!IDisplay)managed!DisplayImpl_WinAPI(managers(), tuple(monitor, alloc), alloc);
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
        
        if (hIcon !is null)
            DestroyIcon(hIcon);
        if (hCursor !is null)
            DestroyCursor(hCursor);
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
            rect.right = point.x;
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
        
        ShowWindow(hwnd, SW_SHOWNORMAL);
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
        if (hIcon !is null)
            DestroyIcon(hIcon);
        
        HDC hFrom = GetDC(null);
        HDC hMemoryDC = CreateCompatibleDC(hFrom);
        
        hIcon = imageToIcon_WinAPI(from, hMemoryDC, alloc);
        
        if (hIcon) {
            SendMessageA(hwnd, WM_SETICON, cast(WPARAM)ICON_BIG, cast(LPARAM)hIcon);
            SendMessageA(hwnd, WM_SETICON, cast(WPARAM)ICON_SMALL, cast(LPARAM)hIcon);
            
            if (!taskbarTrayWindow.isNull &&
                cast(HWND)taskbarTrayWindow.__handle is hwnd) {
                uiInstance.__getFeatureNotificationTray().setNotificationWindow(taskbarTrayWindow);
            }
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
        hotspot.x *= cast(ushort)(toSize.x > image.width ? (toSize.x / cast(float)image.width) : (image.width / cast(float)toSize.x));
        hotspot.y *= cast(ushort)(toSize.y > image.height ? (toSize.y / cast(float)image.height) : (image.height / cast(float)toSize.y));
        
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
        
        hCursor = CreateCursor(null, cast(DWORD)hotspot.x, cast(DWORD)hotspot.y, cast(int)toSize.x, cast(int)toSize.y, ii.hbmColor, ii.hbmMask);
        
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
                if (onCloseDel !is null)
                    onCloseDel();
            } catch (Exception e) {}
        }
    }
}

final class WinAPI_DropTarget : IDropTarget {
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
