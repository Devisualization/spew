module cf.spew.implementation.misc.timer;
import cf.spew.miscellaneous.timer;
import cf.spew.implementation.instance;
import devisualization.bindings.libuv;
import core.time : Duration;

abstract class TimerImpl : ITimer {
	package(cf.spew.implementation) {
		Duration theTimeout;
		bool isStopped;

		TimerEventDel onEventDel;
		TimerStoppedDel onStoppedDel;
	}

	this(Duration duration) {
		theTimeout = duration;
	}

	~this() {
		if (!isStopped) stop();
	}

	@property {
		Duration timeout() { return theTimeout; }
		bool isRunning() { return !isStopped; }

		void onEvent(TimerEventDel del) { onEventDel = del; }
		void onStopped(TimerStoppedDel del) { onStoppedDel = del; }
	}
}

// http://docs.libuv.org/en/v1.x/timer.html
class LibUVTimer : TimerImpl {
	package(cf.spew.implementation) {
		uv_timer_t ctx;
		LibUVTimer self;
	}

	this(Duration duration) {
		import cf.spew.event_loop.wells.libuv;
		super(duration);

		libuv.uv_timer_init(getThreadLoop_UV(), &ctx);
		self = this;
		ctx.data = cast(void*)&self;

		ulong timeout = cast(ulong)duration.total!"msecs";
		libuv.uv_timer_start(&ctx, &libuvTimerCB, timeout, timeout);
	}

	void stop() {
		if (!isStopped) {
			isStopped = true;
			libuv.uv_timer_stop(&ctx);
			libuv.uv_close(cast(uv_handle_t*)&ctx, null);

			if (onStoppedDel !is null)
				onStoppedDel(this);
		}
	}
}

extern(C) {
	void libuvTimerCB(uv_timer_t* handle) {
		LibUVTimer watcher = *cast(LibUVTimer*)handle.data;

		if (watcher.onEventDel !is null)
			watcher.onEventDel(watcher);
	}
}

version(Windows) {
	// create a window specifically for this! DO NOT USE CALLBACK
	// SetTimer https://msdn.microsoft.com/en-us/library/windows/desktop/ms644906(v=vs.85).aspx
	// KillTimer https://msdn.microsoft.com/en-us/library/windows/desktop/ms644903(v=vs.85).aspx
	class WinAPITimer : TimerImpl {
		import core.sys.windows.windows;
		import cf.spew.event_loop.wells.winapi;

		HWND hwnd;
		WNDCLASSEXW wndClass;
		HINSTANCE hInstance;
		EventLoopAlterationCallbacks impl_callbacks_struct;
		UINT_PTR timerPtr;
		shared(Miscellaneous_Instance) instance;

		static wstring ClassTimerNameW = __MODULE__ ~ ":TimerClass"w;

		~this() {
			if (!isStopped) {
				stop();
			}
		}

		this(shared(Miscellaneous_Instance) instance, Duration duration) {
			super(duration);
			this.instance = instance;

			hInstance = GetModuleHandleW(null);

			if (GetClassInfoExW(hInstance, cast(wchar*)ClassTimerNameW.ptr, &wndClass) == 0) {
				wndClass.cbSize = WNDCLASSEXW.sizeof;
				wndClass.hInstance = hInstance;
				wndClass.lpszClassName = cast(wchar*)ClassTimerNameW.ptr;
				wndClass.lpfnWndProc = &callbackWindowHandler;
				
				RegisterClassExW(&wndClass);
			}

			hwnd = CreateWindowExW(
				0, cast(wchar*)ClassTimerNameW.ptr, null,
				0,
				0, 0,
				0, 0,
				null, null, hInstance, null);

			SetWindowLongPtrW(hwnd, GWLP_USERDATA, cast(size_t)&impl_callbacks_struct);
			SetTimer(hwnd, 0, cast(UINT)duration.total!"msecs", null);
			instance.timerToIdMapper[cast(size_t)hwnd] = cast(shared)this;
		}
		
		void stop() {
			if (!isStopped) {
				isStopped = true;
				KillTimer(hwnd, timerPtr);
				DestroyWindow(hwnd);
				instance.timerToIdMapper.remove(cast(size_t)hwnd);

				if (onStoppedDel !is null)
					onStoppedDel(this);
			}
		}
	}
}
