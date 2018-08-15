module cf.spew.implementation.windowing.utilities.winapi;
version (Windows):
import cf.spew.implementation.windowing.utilities.misc;
import cf.spew.implementation.windowing.display.winapi;
import cf.spew.implementation.windowing.window.winapi;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.display.defs;
import cf.spew.ui.window.defs;
import cf.spew.ui.context.defs;
import devisualization.image : ImageStorage;
import stdx.allocator : IAllocator, ISharedAllocator, processAllocator,
    theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
import std.experimental.color : RGB8, RGBA8;
import derelict.util.sharedlib;
import core.sys.windows.windows;

enum WindowDWStyles : DWORD {
    Dialog = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX,
    DialogEx = WS_EX_ACCEPTFILES | WS_EX_APPWINDOW,

    Borderless = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_BORDER | WS_MINIMIZEBOX,
    BorderlessEx = WS_EX_ACCEPTFILES | WS_EX_APPWINDOW,

    Popup = WS_POPUPWINDOW |
        WS_CAPTION | WS_SYSMENU | WS_BORDER | WS_MINIMIZEBOX,
        PopupEx = WS_EX_ACCEPTFILES | WS_EX_APPWINDOW | WS_EX_TOPMOST, Fullscreen = WS_POPUP |
        WS_CLIPCHILDREN | WS_CLIPSIBLINGS, FullscreenEx = WS_EX_APPWINDOW | WS_EX_TOPMOST,

        NoDecorations = WS_POPUP, NoDecorationsEx = WS_EX_TOPMOST | WS_EX_TRANSPARENT
}

static wstring ClassNameW = __MODULE__ ~ ":Class"w;

struct PHYSICAL_MONITOR {
    HANDLE hPhysicalMonitor;
    WCHAR[PHYSICAL_MONITOR_DESCRIPTION_SIZE] szPhysicalMonitorDescription;
}

enum {
    PHYSICAL_MONITOR_DESCRIPTION_SIZE = 128,
    MC_CAPS_BRIGHTNESS = 0x00000002,

    NOTIFYICON_VERSION_4 = 4,
    NIF_SHOWTIP = 0x00000080,
    NIF_REALTIME = 0x00000040,
}

extern (Windows) {
    // dxva2
    BOOL function(HANDLE hMonitor, LPDWORD pdwMonitorCapabilities,
            LPDWORD pdwSupportedColorTemperatures) GetMonitorCapabilities;
    BOOL function(HANDLE hMonitor, LPDWORD pdwMinimumBrightness,
            LPDWORD pdwCurrentBrightness, LPDWORD pdwMaximumBrightness) GetMonitorBrightness;
    BOOL function(HMONITOR hMonitor, DWORD dwPhysicalMonitorArraySize,
            PHYSICAL_MONITOR* pPhysicalMonitorArray) GetPhysicalMonitorsFromHMONITOR;

    // shell32
    HRESULT function(NOTIFYICONIDENTIFIER*, RECT*) Shell_NotifyIconGetRect;

    // user32
    BOOL function(POINT*, SIZE*, UINT, RECT*, RECT*) CalculatePopupWindowPosition;
}

__gshared SharedLib dxva2, shell32, user32;

//

ImageStorage!RGB8 screenshotImpl_WinAPI(IAllocator alloc, HDC hFrom, uint width, uint height) {
    HDC hMemoryDC = CreateCompatibleDC(hFrom);
    HBITMAP hBitmap = CreateCompatibleBitmap(hFrom, width, height);

    HBITMAP hOldBitmap = SelectObject(hMemoryDC, hBitmap);
    BitBlt(hMemoryDC, 0, 0, width, height, hFrom, 0, 0, SRCCOPY);

    auto storage = bitmapToImage_WinAPI(hBitmap, hMemoryDC, vec2!size_t(width, height), alloc);

    hBitmap = SelectObject(hMemoryDC, hOldBitmap);
    DeleteDC(hMemoryDC);

    return storage;
}

ImageStorage!RGB8 bitmapToImage_WinAPI(HBITMAP hBitmap, HDC hMemoryDC,
        vec2!size_t size_, IAllocator alloc) {
    import devisualization.image.storage.base : ImageStorageHorizontal;
    import devisualization.image.interfaces : imageObject;

    size_t dwBmpSize = ((size_.x * 32 + 31) / 32) * 4 * size_.y;
    ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
    auto storage = imageObject!(ImageStorageHorizontal!RGB8)(size_.x, size_.y, alloc);

    BITMAPINFOHEADER bi;

    bi.biSize = BITMAPINFOHEADER.sizeof;
    bi.biWidth = cast(int)size_.x;
    bi.biHeight = cast(int)size_.y;
    bi.biPlanes = 1;
    bi.biBitCount = 32;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = 0;
    bi.biXPelsPerMeter = 0;
    bi.biYPelsPerMeter = 0;
    bi.biClrUsed = 0;
    bi.biClrImportant = 0;

    BITMAPINFO bitmapInfo;
    bitmapInfo.bmiHeader = bi;

    GetDIBits(hMemoryDC, hBitmap, 0, cast(int)size_.y, buffer.ptr, &bitmapInfo, DIB_RGB_COLORS);

    size_t x;
    size_t y = size_.y - 1;
    for (size_t i = 0; i < buffer.length; i += 4) {
        RGB8 c = RGB8(buffer[i + 2], buffer[i + 1], buffer[i]);

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

ImageStorage!RGBA8 bitmapToAlphaImage_WinAPI(HBITMAP hBitmap, HDC hMemoryDC,
        vec2!size_t size_, IAllocator alloc) {
    import devisualization.image.storage.base : ImageStorageHorizontal;
    import devisualization.image.interfaces : imageObject;

    size_t dwBmpSize = ((size_.x * 32 + 31) / 32) * 4 * size_.y;
    ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);
    auto storage = imageObject!(ImageStorageHorizontal!RGBA8)(size_.x, size_.y, alloc);

    BITMAPINFOHEADER bi;

    bi.biSize = BITMAPINFOHEADER.sizeof;
    bi.biWidth = cast(int)size_.x;
    bi.biHeight = cast(int)size_.y;
    bi.biPlanes = 1;
    bi.biBitCount = 32;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = 0;
    bi.biXPelsPerMeter = 0;
    bi.biYPelsPerMeter = 0;
    bi.biClrUsed = 0;
    bi.biClrImportant = 0;

    BITMAPINFO bitmapInfo;
    bitmapInfo.bmiHeader = bi;

    GetDIBits(hMemoryDC, hBitmap, 0, cast(int)size_.y, buffer.ptr, &bitmapInfo, DIB_RGB_COLORS);

    size_t x;
    size_t y = size_.y - 1;
    for (size_t i = 0; i < buffer.length; i += 4) {
        RGBA8 c = RGBA8(buffer[i + 2], buffer[i + 1], buffer[i], 255);

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

HBITMAP imageToBitmap_WinAPI(ImageStorage!RGB8 from, HDC hMemoryDC, IAllocator alloc) {
    size_t dwBmpSize = ((from.width * 32 + 31) / 32) * 4 * from.height;
    ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);

    HICON ret;

    size_t x;
    size_t y = from.height - 1;
    for (size_t i = 0; i < buffer.length; i += 4) {
        RGB8 c = from[x, y];

        buffer[i] = c.b.value;
        buffer[i + 1] = c.g.value;
        buffer[i + 2] = c.r.value;
        buffer[i + 3] = 255;

        x++;
        if (x == from.width) {
            x = 0;
            if (y == 0)
                break;
            y--;
        }
    }

    HBITMAP hBitmap = CreateBitmap(cast(uint)from.width, cast(uint)from.height, 1, 32, buffer.ptr);
    alloc.dispose(buffer);
    return hBitmap;
}

HBITMAP imageToAlphaBitmap_WinAPI(ImageStorage!RGBA8 from, HDC hMemoryDC, IAllocator alloc) {
    size_t dwBmpSize = ((from.width * 32 + 31) / 32) * 4 * from.height;
    ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);

    HICON ret;

    size_t x;
    size_t y = from.height - 1;
    for (size_t i = 0; i < buffer.length; i += 4) {
        RGBA8 c = from[x, y];

        buffer[i] = c.b.value;
        buffer[i + 1] = c.g.value;
        buffer[i + 2] = c.r.value;
        buffer[i + 3] = c.a.value;

        x++;
        if (x == from.width) {
            x = 0;
            if (y == 0)
                break;
            y--;
        }
    }

    HBITMAP hBitmap = CreateBitmap(cast(uint)from.width, cast(uint)from.height, 1, 32, buffer.ptr);
    alloc.dispose(buffer);
    return hBitmap;
}

HBITMAP imageToAlphaBitmap_WinAPI(shared(ImageStorage!RGBA8) from,
        HDC hMemoryDC, shared(ISharedAllocator) alloc) {
    size_t dwBmpSize = ((from.width * 32 + 31) / 32) * 4 * from.height;
    ubyte[] buffer = alloc.makeArray!ubyte(dwBmpSize);

    HICON ret;

    size_t x;
    size_t y = from.height - 1;
    for (size_t i = 0; i < buffer.length; i += 4) {
        RGBA8 c = from[x, y];

        buffer[i] = c.b.value;
        buffer[i + 1] = c.g.value;
        buffer[i + 2] = c.r.value;
        buffer[i + 3] = c.a.value;

        x++;
        if (x == from.width) {
            x = 0;
            if (y == 0)
                break;
            y--;
        }
    }

    HBITMAP hBitmap = CreateBitmap(cast(uint)from.width, cast(uint)from.height, 1, 32, buffer.ptr);
    alloc.dispose(buffer);
    return hBitmap;
}

HICON imageToIcon_WinAPI(ImageStorage!RGBA8 from, HDC hMemoryDC, IAllocator alloc) {
    HBITMAP hBitmap = imageToAlphaBitmap_WinAPI(from, hMemoryDC, alloc);
    HICON ret = bitmapToIcon_WinAPI(hBitmap, hMemoryDC, vec2!size_t(from.width, from.height));

    scope (exit)
        DeleteObject(hBitmap);

    return ret;
}

HICON imageToIcon_WinAPI(shared(ImageStorage!RGBA8) from, HDC hMemoryDC,
        shared(ISharedAllocator) alloc) {
    HBITMAP hBitmap = imageToAlphaBitmap_WinAPI(from, hMemoryDC, alloc);
    HICON ret = bitmapToIcon_WinAPI(hBitmap, hMemoryDC, vec2!size_t(from.width, from.height));

    scope (exit)
        DeleteObject(hBitmap);

    return ret;
}

HICON bitmapToIcon_WinAPI(HBITMAP hBitmap, HDC hMemoryDC, vec2!size_t size_) {
    HICON ret;
    HBITMAP hbmMask = CreateCompatibleBitmap(hMemoryDC, cast(uint)size_.x, cast(uint)size_.y);

    ICONINFO ii;
    ii.fIcon = true;
    ii.hbmColor = hBitmap;
    ii.hbmMask = hbmMask;

    ret = CreateIconIndirect(&ii);

    DeleteObject(hbmMask);

    return ret;
}

HBITMAP resizeBitmap_WinAPI(HBITMAP hBitmap, HDC hDC, vec2!size_t toSize, vec2!size_t fromSize) {
    HDC hMemDC1 = CreateCompatibleDC(hDC);
    HBITMAP hBitmap1 = CreateCompatibleBitmap(hDC, cast(int)toSize.x, cast(int)toSize.y);
    HGDIOBJ hOld1 = SelectObject(hMemDC1, hBitmap1);

    HDC hMemDC2 = CreateCompatibleDC(hDC);
    HGDIOBJ hOld2 = SelectObject(hMemDC2, hBitmap);

    BITMAP bitmap;
    GetObjectW(hBitmap, BITMAP.sizeof, &bitmap);

    StretchBlt(hMemDC1, 0, 0, cast(int)toSize.x, cast(int)toSize.y, hMemDC2, 0,
            0, cast(int)fromSize.x, cast(int)fromSize.y, SRCCOPY);

    SelectObject(hMemDC1, hOld1);
    SelectObject(hMemDC2, hOld2);
    DeleteDC(hMemDC1);
    DeleteDC(hMemDC2);

    return hBitmap1;
}

struct GetDisplays_WinAPI {
    IAllocator alloc;
    HandleAppender!IDisplay displays;

    void call() {
        displays = HandleAppender!IDisplay(alloc);
        EnumDisplayMonitors(null, null, &callbackGetDisplays_WinAPI,
                cast(LPARAM)cast(void*)&this);
    }
}

struct GetPrimaryDisplay_WinAPI {
    IAllocator alloc;
    IDisplay display;

    void call() {
        EnumDisplayMonitors(null, null, &callbackGetPrimaryDisplay_WinAPI,
                cast(LPARAM)cast(void*)&this);
    }
}

struct GetWindows_WinAPI {
    IAllocator alloc;
    IDisplay display;

    HandleAppender!IWindow windows;

    void call() {
        windows = HandleAppender!IWindow(alloc);
        EnumWindows(&callbackGetWindows_WinAPI, cast(LPARAM)&this);
    }
}

extern (Windows) {
    int callbackGetDisplays_WinAPI(HMONITOR hMonitor, HDC, LPRECT, LPARAM lParam) nothrow {
        GetDisplays_WinAPI* ctx = cast(GetDisplays_WinAPI*)lParam;

        try {
            DisplayImpl_WinAPI display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc);
            ctx.displays.add(display);
        } catch (Exception e) {
        }

        return true;
    }

    int callbackGetPrimaryDisplay_WinAPI(HMONITOR hMonitor, HDC, LPRECT, LPARAM lParam) nothrow {
        GetPrimaryDisplay_WinAPI* ctx = cast(GetPrimaryDisplay_WinAPI*)lParam;

        MONITORINFOEXA info;
        info.cbSize = MONITORINFOEXA.sizeof;
        GetMonitorInfoA(hMonitor, &info);

        if ((info.dwFlags & MONITORINFOF_PRIMARY) != MONITORINFOF_PRIMARY) {
            return true;
        }

        try {
            ctx.display = ctx.alloc.make!DisplayImpl_WinAPI(hMonitor, ctx.alloc);
            return false;
        } catch (Exception e) {
        }
        return true;
    }

    int callbackGetWindows_WinAPI(HWND hwnd, LPARAM lParam) nothrow {
        GetWindows_WinAPI* ctx = cast(GetWindows_WinAPI*)lParam;

        if (!IsWindowVisible(hwnd))
            return true;

        RECT rect;
        GetWindowRect(hwnd, &rect);

        if (rect.right - rect.left == 0 || rect.bottom - rect.top == 0)
            return true;

        try {
            WindowImpl_WinAPI window = ctx.alloc.make!WindowImpl_WinAPI(hwnd,
                    cast(IContext)null, ctx.alloc);

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
        } catch (Exception e) {
        }

        return true;
    }
}

struct NOTIFYICONIDENTIFIER {
    DWORD cbSize;
    HWND hWnd;
    UINT uID;
    GUID guidItem;
}

enum {
    NIN_SELECT = 0x0400,

    TPM_WORKAREA = 0x10000,
    TPM_VERTICAL = 0x0040,
    TPM_VCENTERALIGN = 0x0010,
    TPM_CENTERALIGN = 0x0004,
}
