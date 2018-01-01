module cf.spew.implementation.misc.timer;
import cf.spew.miscellaneous.timer;
import devisualization.bindings.libuv.uv;
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

		uv_timer_init(getThreadLoop_UV(), &ctx);
		self = this;
		ctx.data = cast(void*)&self;

		ulong timeout = cast(ulong)duration.total!"msecs";
		uv_timer_start(&ctx, &libuvTimerCB, timeout, timeout);
	}

	void stop() {
		if (!isStopped) {
			isStopped = true;
			uv_timer_stop(&ctx);
			uv_close(cast(uv_handle_t*)&ctx, null);

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
		this(Duration duration) {
			super(duration);
			
			assert(0);
		}
		
		void stop() {
			assert(0);
		}
	}
}