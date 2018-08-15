module cf.spew.implementation.instance.ui.winapi;
version (Windows):
import cf.spew.implementation.instance.state : taskbarTrayWindow,
    taskbarTrayWindowThread;
import cf.spew.implementation.instance.ui.base;
import cf.spew.implementation.windowing.window_creator.winapi : WindowCreatorImpl_WinAPI;
import cf.spew.implementation.windowing.window.winapi : WindowImpl_WinAPI;
import cf.spew.implementation.windowing.utilities.winapi : GetPrimaryDisplay_WinAPI,
    GetDisplays_WinAPI, GetWindows_WinAPI, NOTIFYICON_VERSION_4,
    imageToIcon_WinAPI, NIF_SHOWTIP, NIF_REALTIME;
import cf.spew.ui.features.notificationmessage;
import cf.spew.ui.features.clipboard;
import cf.spew.ui.features.notificationtray;
import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint,
    IRenderPointCreator;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage;
import std.typecons : tuple;
import std.experimental.color : RGBA8;
import stdx.allocator : IAllocator, ISharedAllocator, theAllocator, makeArray;
import core.time : Duration, seconds, nsecs;
import core.thread : Thread;
import core.sys.windows.windows : NOTIFYICONDATAW, HWND, OpenClipboard,
    GetClipboardData, HANDLE, CF_UNICODETEXT, GlobalLock, GlobalUnlock,
    GetClipboardData, CF_TEXT, CloseClipboard, HGLOBAL, HICON, HDC,
    EmptyClipboard, GlobalAlloc, GMEM_MOVEABLE, Shell_NotifyIconW, NIF_ICON,
    NIF_MESSAGE, SendMessageW, GetClassLongPtr, NIM_MODIFY, NIM_ADD, NIM_DELETE,
    NIM_SETVERSION, SetClipboardData, WM_GETICON, WPARAM, GCL_HICON, ICON_SMALL,
    NIF_INFO, GetDC, CreateCompatibleDC, DeleteDC, ReleaseDC, DeleteObject;

final class UIInstance_WinAPI : UIInstance, Feature_NotificationMessage,
    Feature_Management_Clipboard, Feature_NotificationTray {
        NOTIFYICONDATAW taskbarIconNID;
        size_t maxClipboardSizeV = size_t.max;

        this(shared(ISharedAllocator) allocator) shared {
            super(allocator);
        }

        override {
            managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
                return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(),
                        tuple(alloc), alloc);
            }

            @property {
                managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
                    GetPrimaryDisplay_WinAPI ctx = GetPrimaryDisplay_WinAPI(alloc);
                    ctx.call;

                    if (ctx.display is null)
                        return managed!IDisplay.init;
                    else
                        return managed!IDisplay(ctx.display,
                                managers(ReferenceCountedManager()), alloc);
                }

                managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
                    GetDisplays_WinAPI ctx = GetDisplays_WinAPI(alloc);
                    ctx.call;
                    return managed!(IDisplay[])(ctx.displays,
                            managers(ReferenceCountedManager()), alloc);
                }

                managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
                    GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc);
                    ctx.call;
                    return managed!(IWindow[])(ctx.windows,
                            managers(ReferenceCountedManager()), alloc);
                }
            }

            // clipboard

            shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
                return OpenClipboard(null) != 0 ? this : null;
            }

            @property {
                void maxClipboardDataSize(size_t amount) shared {
                    maxClipboardSizeV = amount;
                }

                size_t maxClipboardDataSize() shared {
                    return maxClipboardSizeV;
                }

                managed!string clipboardText(IAllocator alloc, Duration timeout = 0.seconds) shared {
                    import std.utf : byChar, codeLength;

                    char[] ret;

                    HANDLE h = GetClipboardData(CF_UNICODETEXT);
                    if (h !is null) {
                        wchar* theData = cast(wchar*)GlobalLock(h);
                        size_t theDataLength, realDataLength;
                        while (theData[theDataLength++] != 0) {
                        }
                        wchar[] theData2 = theData[0 .. theDataLength - 1];

                        realDataLength = theData2.codeLength!char;
                        ret = alloc.makeArray!char(realDataLength);
                        size_t offset;
                        foreach (c; theData2.byChar)
                            ret[offset++] = c;

                        GlobalUnlock(h);
                    } else {
                        h = GetClipboardData(CF_TEXT);

                        if (h !is null) {
                            char* theData = cast(char*)GlobalLock(h);
                            size_t theDataLength;
                            while (theData[theDataLength++] != 0) {
                            }

                            ret = alloc.makeArray!char(theDataLength - 1);
                            ret[] = theData[0 .. theDataLength];

                            GlobalUnlock(h);
                        }
                    }

                    CloseClipboard();

                    if (ret !is null)
                        return managed!string(cast(string)ret, managers(), alloc);
                    else
                        return managed!string.init;
                }

                void clipboardText(scope string text) shared {
                    import std.utf : byWchar, codeLength;

                    EmptyClipboard();

                    size_t realLength = text.codeLength!char;
                    HGLOBAL hglb = GlobalAlloc(GMEM_MOVEABLE, (realLength + 1) * wchar.sizeof);

                    if (hglb !is null) {
                        wchar* wtext = cast(wchar*)GlobalLock(hglb);
                        size_t offset;

                        foreach (c; text.byWchar)
                            wtext[offset++] = c;

                        GlobalUnlock(hglb);
                        SetClipboardData(CF_UNICODETEXT, hglb);
                    }

                    CloseClipboard();
                }
            }

            // notifications

            shared(Feature_NotificationTray) __getFeatureNotificationTray() shared {
                return this;
            }

            @property {
                managed!IWindow getNotificationWindow(IAllocator alloc) shared {
                    if (cast()taskbarTrayWindow is managed!IWindow.init ||
                            taskbarTrayWindowThread != Thread.getThis().id)
                        return managed!IWindow.init;
                    else
                        return cast()taskbarTrayWindow;
                }

                void setNotificationWindow(managed!IWindow window) shared {
                    import cf.spew.event_loop.wells.winapi : AllocatedWM_USER;

                    bool modify;

                    if (!(cast()taskbarTrayWindow).isNull) {
                        HWND primaryHandle = cast(HWND)(cast()taskbarTrayWindow).__handle;
                        if (!window.isNull && primaryHandle is cast(HWND)(cast()window).__handle)
                            modify = true;
                        else {
                            Shell_NotifyIconW(NIM_DELETE, cast(NOTIFYICONDATAW*)&taskbarIconNID);
                            cast()taskbarTrayWindow = managed!IWindow.init;
                            taskbarIconNID = typeof(taskbarIconNID).init;
                        }
                    }

                    if (!window.isNull) {
                        cast()taskbarTrayWindow = window;
                        taskbarTrayWindowThread = Thread.getThis().id;

                        taskbarIconNID = NOTIFYICONDATAW.init;
                        taskbarIconNID.cbSize = NOTIFYICONDATAW.sizeof;
                        taskbarIconNID.uVersion = NOTIFYICON_VERSION_4;
                        taskbarIconNID.uFlags = NIF_ICON | NIF_MESSAGE;
                        taskbarIconNID.hIcon = cast(shared)(cast(managed!WindowImpl_WinAPI)cast()taskbarTrayWindow)
                            .hIcon;
                        taskbarIconNID.hWnd = cast(shared(HWND))(cast()taskbarTrayWindow).__handle;
                        taskbarIconNID.uCallbackMessage = AllocatedWM_USER.NotificationTray;

                        if (taskbarIconNID.hIcon is null)
                            taskbarIconNID.hIcon = cast(shared(HICON))SendMessageW(cast(HWND)taskbarIconNID.hWnd,
                                    WM_GETICON, cast(WPARAM)ICON_SMALL, 80);
                        if (taskbarIconNID.hIcon is null)
                            taskbarIconNID.hIcon = cast(shared(HICON))GetClassLongPtr(
                                    cast(HWND)taskbarIconNID.hWnd, GCL_HICON);

                        if (modify)
                            Shell_NotifyIconW(NIM_MODIFY, cast(NOTIFYICONDATAW*)&taskbarIconNID);
                        else
                            Shell_NotifyIconW(NIM_ADD, cast(NOTIFYICONDATAW*)&taskbarIconNID);
                        Shell_NotifyIconW(NIM_SETVERSION, cast(NOTIFYICONDATAW*)&taskbarIconNID);
                    }
                }
            }

            bool haveNotificationWindow() shared {
                return cast()taskbarTrayWindow is managed!IWindow.init;
            }

            shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared {
                return this;
            }

            void notify(shared(ImageStorage!RGBA8) icon, dstring title,
                    dstring text, shared(ISharedAllocator) alloc) shared {
                import std.utf : byUTF;

                if ((cast()taskbarTrayWindow).isNull)
                    return;

                NOTIFYICONDATAW nid = cast(NOTIFYICONDATAW)taskbarIconNID;
                nid.cbSize = NOTIFYICONDATAW.sizeof;
                nid.uVersion = NOTIFYICON_VERSION_4;
                nid.uFlags = NIF_ICON | NIF_SHOWTIP | NIF_INFO | NIF_REALTIME;
                nid.hWnd = cast(HWND)(cast()taskbarTrayWindow).__handle;

                size_t i;
                foreach (c; byUTF!wchar(title)) {
                    if (i >= nid.szInfoTitle.length - 1) {
                        nid.szInfoTitle[i] = cast(wchar)0;
                        break;
                    } else
                        nid.szInfoTitle[i] = c;

                    i++;
                    if (i == title.length)
                        nid.szInfoTitle[i] = cast(wchar)0;
                }

                i = 0;
                foreach (c; byUTF!wchar(text)) {
                    if (i >= nid.szInfo.length - 1) {
                        nid.szInfo[i] = cast(wchar)0;
                        break;
                    } else
                        nid.szInfo[i] = c;

                    i++;
                    if (i == text.length)
                        nid.szInfo[i] = cast(wchar)0;
                }

                HDC hFrom = GetDC(null);
                HDC hMemoryDC = CreateCompatibleDC(hFrom);

                scope (exit) {
                    DeleteDC(hMemoryDC);
                    ReleaseDC(null, hFrom);
                }

                if (icon !is null)
                    nid.hIcon = imageToIcon_WinAPI(icon, hMemoryDC, alloc);

                Shell_NotifyIconW(NIM_MODIFY, &nid);
                Shell_NotifyIconW(NIM_MODIFY, cast(NOTIFYICONDATAW*)&taskbarIconNID);
                DeleteObject(nid.hIcon);
            }

            void clearNotifications() shared {
            }
        }
    }
