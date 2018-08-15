module cf.spew.implementation.misc.timer.base;
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

    ~this() {
        if (!isStopped)
            stop();
    }

    @property {
        Duration timeout() {
            return theTimeout;
        }

        bool isRunning() {
            return !isStopped;
        }

        void onEvent(TimerEventDel del) {
            onEventDel = del;
        }

        void onStopped(TimerStoppedDel del) {
            onStoppedDel = del;
        }
    }
}
