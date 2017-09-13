module cf.spew.bindings.libuv.uv_threadpool;
import cf.spew.bindings.libuv.uv : uv_loop_s;

__gshared nothrow @nogc @system extern(C):

struct uv__work {
	extern(C) void function(uv__work* w) work;
	extern(C) void function(uv__work* w, int status) done;
	uv_loop_s* loop;
	void*[2] wq;
}