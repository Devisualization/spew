module cf.spew.implementation.misc.timer;
import cf.spew.miscellaneous.timer;
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

	@property {
		Duration timeout() { return theTimeout; }
		bool isRunning() { return !isStopped; }

		void onEvent(TimerEventDel del) { onEventDel = del; }
		void onStopped(TimerStoppedDel del) { onStoppedDel = del; }
	}
}

// http://docs.libuv.org/en/v1.x/fs_event.html
class LibUVTimer : TimerImpl {
	this(Duration duration) {
		super(duration);

		assert(0);
	}

	void stop() {
		assert(0);
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