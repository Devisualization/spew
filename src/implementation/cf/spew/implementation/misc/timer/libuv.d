module cf.spew.implementation.misc.timer.libuv;
import cf.spew.implementation.misc.timer.base;
import core.time : Duration;
import devisualization.bindings.libuv;

// http://docs.libuv.org/en/v1.x/timer.html
final class LibUVTimer : TimerImpl {
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

extern (C) {
    void libuvTimerCB(uv_timer_t* handle) {
        LibUVTimer watcher = *cast(LibUVTimer*)handle.data;

        if (watcher.onEventDel !is null)
            watcher.onEventDel(watcher);
    }
}
