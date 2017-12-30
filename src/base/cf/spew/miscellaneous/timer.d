module cf.spew.miscellaneous.timer;
import std.functional : toDelegate;
import core.time : Duration;

alias TimerEventDel = void delegate(scope ITimer timer);
alias TimerEventFunc = void function(scope ITimer timer);

alias TimerStoppedDel = void delegate(scope ITimer timer);
alias TimerStoppedFunc = void function(scope ITimer timer);

interface ITimer {
	@property {
		Duration timeout();
		bool isRunning();
	}

	void stop();

	@property {
		void onEvent(TimerEventDel del);
		final void onEvent(TimerEventFunc func) { onEvent = func.toDelegate; }

		void onStopped(TimerStoppedDel del);
		final void onStopped(TimerStoppedFunc func) { onStopped = func.toDelegate; }
	}
}