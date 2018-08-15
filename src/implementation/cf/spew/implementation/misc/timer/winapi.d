module cf.spew.implementation.misc.timer.winapi;
version (Windows):
import cf.spew.implementation.misc.timer.base;
import core.time : Duration;

// create a window specifically for this! DO NOT USE CALLBACK
// SetTimer https://msdn.microsoft.com/en-us/library/windows/desktop/ms644906(v=vs.85).aspx
// KillTimer https://msdn.microsoft.com/en-us/library/windows/desktop/ms644903(v=vs.85).aspx
final class WinAPITimer : TimerImpl {
    import core.sys.windows.windows;
    import cf.spew.event_loop.wells.winapi;
    import cf.spew.implementation.instance.state : timerToIdMapper;

    HWND hwnd;
    WNDCLASSEXW wndClass;
    HINSTANCE hInstance;
    EventLoopAlterationCallbacks impl_callbacks_struct;
    UINT_PTR timerPtr;

    static wstring ClassTimerNameW = __MODULE__ ~ ":TimerClass"w;

    ~this() {
        if (!isStopped) {
            stop();
        }
    }

    this(Duration duration) {
        super(duration);

        hInstance = GetModuleHandleW(null);

        if (GetClassInfoExW(hInstance, cast(wchar*)ClassTimerNameW.ptr, &wndClass) == 0) {
            wndClass.cbSize = WNDCLASSEXW.sizeof;
            wndClass.hInstance = hInstance;
            wndClass.lpszClassName = cast(wchar*)ClassTimerNameW.ptr;
            wndClass.lpfnWndProc = &callbackWindowHandler;

            RegisterClassExW(&wndClass);
        }

        hwnd = CreateWindowExW(0, cast(wchar*)ClassTimerNameW.ptr, null,
                0, 0, 0, 0, 0, null, null, hInstance, null);

        SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(size_t)&impl_callbacks_struct);
        SetTimer(hwnd, 0, cast(UINT)duration.total!"msecs", null);
        timerToIdMapper[cast(size_t)hwnd] = cast(shared)this;
    }

    void stop() {
        if (!isStopped) {
            isStopped = true;
            KillTimer(hwnd, timerPtr);
            DestroyWindow(hwnd);
            timerToIdMapper.remove(cast(size_t)hwnd);

            if (onStoppedDel !is null)
                onStoppedDel(this);
        }
    }
}

