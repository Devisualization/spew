module cf.spew.implementation.consumers.winapi;
version (Windows):
import cf.spew.implementation.consumers.base;
import cf.spew.implementation.instance.state : windowToIdMapper,
    timerToIdMapper;
import cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.windowing.window.winapi;
import cf.spew.implementation.misc.timer.base;
import cf.spew.implementation.misc.timer.winapi;
import cf.spew.events.defs;
import cf.spew.events.windowing;
import cf.spew.events.winapi;
import cf.spew.event_loop.known_implementations;
import cf.spew.event_loop.wells.winapi : AllocatedWM_USER;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.window.features.cursor : WindowCursorStyle;
import cf.spew.miscellaneous.timer : ITimer;
import stdx.allocator : dispose, makeArray, expandArray;
import std.typecons : Nullable;
import core.sys.windows.windows : InvalidateRgn, RECT, LOWORD, HTCLIENT,
    SetCursor, DestroyWindow, WM_ERASEBKGND, IsWindowVisible,
    GetDoubleClickTime, GUID_NULL, SUCCEEDED, POINT, GetWindowRect, SIZE,
    SetWindowPos, SetForegroundWindow, ValidateRgn, WM_LBUTTONDOWN,
    HWND_TOPMOST, SWP_NOSIZE, SWP_SHOWWINDOW, PAINTSTRUCT, HDC, BeginPaint,
    EndPaint, FillRect, HBRUSH, COLOR_WINDOW;

final class EventLoopConsumerImpl_WinAPI : EventLoopConsumerImpl {
    override bool processEvent(ref Event event) shared {
        IWindow window = cast()windowToIdMapper[event.wellData1Value];

        if (window is null) {
            ITimer timer = cast()timerToIdMapper[event.wellData1Value];

            if (timer is null) {
            } else {
                switch (event.type) {
                case Windowing_Events_Types.Window_RequestClose:
                    timer.stop();
                    return true;

                case WinAPI_Events_Types.Window_Timer:
                    if (TimerImpl timer2 = cast(TimerImpl)timer) {
                        tryFunc(timer2.onEventDel, timer);
                    }
                    return true;
                default:
                    return false;
                }
            }
        } else if (WindowImpl_WinAPI w = cast(WindowImpl_WinAPI)window) {
            WindowImpl w2 = cast(WindowImpl)w;

            switch (event.type) {
            case Windowing_Events_Types.Window_Resized:
                InvalidateRgn(event.wellData1Ptr, null, 0);
                tryFunc(w2.onSizeChangeDel, event.windowing.windowResized.newWidth,
                        event.windowing.windowResized.newHeight);
                return true;
            case Windowing_Events_Types.Window_Moved:
                InvalidateRgn(event.wellData1Ptr, null, 0);
                tryFunc(w2.onMoveDel, event.windowing.windowMoved.newX,
                        event.windowing.windowMoved.newY);
                return true;
            case Windowing_Events_Types.Window_Show:
                if (w.oldCursorClipArea != RECT.init)
                    w.lockCursorToWindow;
                tryFunc(w2.onVisibleDel);
                return true;
            case Windowing_Events_Types.Window_CursorScroll:
                tryFunc(w2.onScrollDel, event.windowing.scroll.amount / 120);
                return true;

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
                return handlePaint(event, w, w2);
            case WinAPI_Events_Types.Window_SystemColorsChanged:
                return false;
            case WinAPI_Events_Types.Window_DevModeChanged:
                return false;
            case WinAPI_Events_Types.Window_SetCursor:
                if (LOWORD(event.wellData2Value) == HTCLIENT &&
                        w.cursorStyle != WindowCursorStyle.Indeterminate) {
                    SetCursor(w.hCursor);
                    return true;
                }
                return false;
            case WinAPI_Events_Types.Window_EnterSizeMove:
                return false;
            case WinAPI_Events_Types.Window_ExitSizeMove:
                InvalidateRgn(event.wellData1Ptr, null, 0);
                return true;
            case Windowing_Events_Types.Window_RequestClose:
                if (tryFunc(w2.onRequestCloseDel, true)) {
                    DestroyWindow(event.wellData1Ptr);
                }
                return true;
            case WinAPI_Events_Types.Menu_Click:
                tryFunc(w.menuCallbacks[event.wellData2Value],
                        w.menuItemsIds[event.wellData2Value]);
                return true;

            case WinAPI_Events_Types.Window_DragAndDrop:
                import std.utf : byChar, codeLength;
                import core.sys.windows.windows;

                HDROP hdrop = cast(HDROP)event.wellData2Ptr;
                POINT point;
                DragQueryPoint(hdrop, &point);

                auto alloc = w2.allocator();
                wchar[] buffer1 = alloc.makeArray!wchar(256);
                char[] buffer2 = alloc.makeArray!char(256);

                size_t count, len1, len2;
                while ((len1 = DragQueryFileW(hdrop, cast(uint)count, null, 0)) != 0) {
                    if (buffer1.length < len1) {
                        alloc.expandArray(buffer1, len1 - buffer1.length);
                    }

                    DragQueryFileW(hdrop, cast(uint)count++, buffer1.ptr,
                            cast(uint)buffer1.length);

                    len2 = codeLength!char(buffer1[0 .. len1]);
                    if (buffer2.length < len2) {
                        alloc.expandArray(buffer2, len2 - buffer2.length);
                    }

                    size_t offset;
                    foreach (c; buffer1[0 .. len1].byChar) {
                        buffer2[offset++] = c;
                    }

                    if (w2.onFileDropDel !is null) {
                        try {
                            w2.onFileDropDel(cast(string)buffer2[0 .. len2], point.x, point.y);
                        } catch (Exception e) {
                        }
                    }
                }

                alloc.dispose(buffer1);
                alloc.dispose(buffer2);

                DragFinish(hdrop);
                return true;

            case Windowing_Events_Types.Window_KeyUp:
                tryFunc(w2.onKeyEntryDel, event.windowing.keyInput.key,
                        event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
                tryFunc(w2.onKeyReleaseDel, event.windowing.keyUp.key,
                        event.windowing.keyUp.special, event.windowing.keyUp.modifiers);
                return true;
            case Windowing_Events_Types.Window_KeyDown:
                tryFunc(w2.onKeyPressDel, event.windowing.keyDown.key,
                        event.windowing.keyDown.special, event.windowing.keyDown.modifiers);
                return true;

            default:
                if (event.type == WinAPI_Events_Types.Raw) {
                    switch (event.winapi.raw.message) {
                    case WM_ERASEBKGND:
                        return handlePaint(event, w, w2);

                    case AllocatedWM_USER.NotificationTray:
                        import cf.spew.implementation.windowing.utilities.winapi;

                        switch (LOWORD(event.winapi.raw.lParam)) {
                        case WM_LBUTTONDOWN:
                        case NIN_SELECT:
                            if (IsWindowVisible(event.winapi.raw.hwnd)) {
                                w.hide();

                                w2.notificationTraySW.reset;
                                w2.notificationTraySW.start;
                                tryFunc(w2.onInvisibleDel);
                            } else {
                                // show

                                if (!w2.notificationTraySW.running ||
                                        GetDoubleClickTime() <= w2.notificationTraySW.peek()
                                        .total!"msecs") {
                                    w2.notificationTraySW.reset;

                                    NOTIFYICONIDENTIFIER nii;
                                    nii.cbSize = NOTIFYICONIDENTIFIER.sizeof;
                                    nii.hWnd = w.hwnd;
                                    nii.guidItem = GUID_NULL;

                                    RECT rcIcon;
                                    if (SUCCEEDED(Shell_NotifyIconGetRect(&nii, &rcIcon))) {
                                        POINT ptAnchor;
                                        ptAnchor.x = (rcIcon.left + rcIcon.right) / 2;
                                        ptAnchor.y = (rcIcon.top + rcIcon.bottom) / 2;

                                        RECT rcWindow;
                                        GetWindowRect(w.hwnd, &rcWindow);

                                        SIZE sizeWindow;
                                        sizeWindow.cx = rcWindow.right - rcWindow.left;
                                        sizeWindow.cy = rcWindow.bottom - rcWindow.top;

                                        if (CalculatePopupWindowPosition(&ptAnchor, &sizeWindow,
                                                TPM_VERTICAL | TPM_VCENTERALIGN | TPM_CENTERALIGN | TPM_WORKAREA,
                                                &rcIcon, &rcWindow)) {
                                            SetWindowPos(w.hwnd, HWND_TOPMOST, rcWindow.left, rcWindow.top,
                                                    0, 0, SWP_NOSIZE | SWP_SHOWWINDOW);
                                            tryFunc(w2.onVisibleDel);
                                        }
                                    }

                                    SetForegroundWindow(w.hwnd);
                                }
                            }
                            break;

                        default:
                            break;
                        }
                        return true;

                    case AllocatedWM_USER.NotificationTrayHideFlyout:
                        w.hide();

                        w2.notificationTraySW.reset;
                        w2.notificationTraySW.start;

                        tryFunc(w2.onInvisibleDel);
                        return true;

                    default:
                        return false;
                    }
                }
                break;
            }
        }

        if (super.processEvent(event))
            return true;
        else
            return false;
    }

    @property {
        override Nullable!EventSource pairOnlyWithSource() shared {
            return Nullable!EventSource(EventSources.WinAPI);
        }

        bool onMainThread() shared {
            return true;
        }

        bool onAdditionalThreads() shared {
            return true;
        }
    }

    bool handlePaint(ref Event event, WindowImpl_WinAPI w, WindowImpl w2) shared {
        ValidateRgn(event.wellData1Ptr, null);

        if (w2.context_ is null) {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(event.wellData1Ptr, &ps);
            FillRect(hdc, &ps.rcPaint, cast(HBRUSH)(COLOR_WINDOW + 1));
            EndPaint(event.wellData1Ptr, &ps);
        } else if (w2.onDrawDel is null) {
            w2.context.activate;
            w2.context.deactivate;
        } else {
            tryFunc(w2.onDrawDel);
        }

        return true;
    }
}
