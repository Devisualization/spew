/**
 * Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
module cf.spew.bindings.libuv.uv_unix;
version(Posix):
__gshared extern(C):

import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.sys.posix.dirent;
import core.sys.posix.sys.socket;
import core.sys.posix.netinet.in_;
import core.sys.posix.netinet.tcp;
import core.sys.posix.netdb;
import core.sys.posix.termios;
import core.sys.posix.pwd;
import core.sys.posix.semaphore;
import core.sys.posix.pthread;
import core.sys.posix.signal;

import cf.spew.bindings.libuv.uv;
import cf.spew.bindings.libuv.uv_threadpool;

version(linux) {
	public import cf.spew.bindings.libuv.uv_linux;
} else version(AIX) {
	static assert(0, "Too lazy to implement AIX");
} else version(Solaris) {
	static assert(0, "Too lazy to implement Solaris");
} else version(OSX) {
	public import cf.spew.bindings.libuv.uv_darwin;
} else version(BSD) {
	public import cf.spew.bindings.libuv.uv_bsd;
} else version(FreeBSD) {
	public import cf.spew.bindings.libuv.uv_bsd;
} else version(OpenBSD) {
	public import cf.spew.bindings.libuv.uv_bsd;
} else static assert(0, "Unknown Posix system");

enum {
	///
	NI_MAXHOST = 1025,
	///
	NI_MAXSERV = 32
}

static if (!__traits(compiles, {mixin UV_IO_PRIVATE_PLATFORM_FIELDS;})) {
	mixin template UV_IO_PRIVATE_PLATFORM_FIELDS() {}
}

///
alias uv__io_cb = void function(uv_loop_s* loop, uv__io_s* w, uint events);
///
alias uv__io_t = uv__io_s;

///
struct uv__io_s {
	///
	uv__io_cb cb;
	///
	void*[2] pending_queue;
	///
	void*[2] watcher_queue;
	/// Pending event mask i.e. mask at next tick.
	uint pevents;
	/// Current event mask.
	uint events;
	///
	int fd;
	///
	mixin UV_IO_PRIVATE_PLATFORM_FIELDS;
}

///
alias uv__async_cb = void function(uv_loop_s* loop, uv__async* w, uint nevents);

///
struct uv__async {
	///
	uv__async_cb cb;
	///
	uv__io_t io_watcher;
	///
	int wfd;
}

static if (!__traits(compiles, {alias T = UV_PLATFORM_SEM_T;})) {
	///
	alias UV_PLATFORM_SEM_T = sem_t;
}

static if (!__traits(compiles, {mixin UV_PLATFORM_LOOP_FIELDS;})) {
	mixin template UV_PLATFORM_LOOP_FIELDS() {}
}

static if (!__traits(compiles, {mixin UV_PLATFORM_FS_EVENT_FIELDS;})) {
	mixin template UV_PLATFORM_FS_EVENT_FIELDS() {}
}

static if (!__traits(compiles, {mixin UV_STREAM_PRIVATE_PLATFORM_FIELDS;})) {
	mixin template UV_STREAM_PRIVATE_PLATFORM_FIELDS() {}
}

/// Note: May be cast to struct iovec. See writev(2).
struct uv_buf_t {
	///
	char* base;
	///
	size_t len;
}

///
alias uv_file = int;
///
alias uv_os_sock_t = int;
///
alias uv_os_fd_t = int;

///
alias UV_ONCE_INIT = PTHREAD_ONCE_INIT;

///
alias
	///
	uv_once_t = pthread_once_t,
	///
	uv_thread_t = pthread_t,
	///
	uv_mutex_t = pthread_mutex_t,
	///
	uv_rwlock_t = pthread_rwlock_t,
	///
	uv_sem_t = UV_PLATFORM_SEM_T,
	///
	uv_cond_t = pthread_cond_t,
	///
	uv_key_t = pthread_key_t,
	///
	uv_barrier_t = pthread_barrier_t;


/// Platform-specific definitions for uv_spawn support.
alias
	///
	uv_gid_t =gid_t,
	///
	uv_uid_t = uid_t;

///
alias uv__dirent_t = dirent;

static if (__traits(compiles, { auto v = DT_UNKNOWN; })) {
	static if (__traits(compiles, { auto v = DT_REG; })) {
		alias UV__DT_FILE = DT_REG;
	} else {
		enum UV__DT_FILE = -1;
	}
	static if (__traits(compiles, { auto v = DT_DIR; })) {
		alias UV__DT_DIR = DT_DIR;
	} else {
		enum UV__DT_DIR = -2;
	}
	static if (__traits(compiles, { auto v = DT_LNK; })) {
		alias UV__DT_LINK = DT_LNK;
	} else {
		enum UV__DT_LINK = -3;
	}
	static if (__traits(compiles, { auto v = DT_FIFO; })) {
		alias UV__DT_FIFO = DT_FIFO;
	} else {
		enum UV__DT_FIFO = -4;
	}
	static if (__traits(compiles, { auto v = DT_SOCK; })) {
		alias UV__DT_SOCKET = DT_SOCK;
	} else {
		enum UV__DT_SOCKET = -5;
	}
	static if (__traits(compiles, { auto v = DT_CHR; })) {
		alias UV__DT_CHAR = DT_CHR;
	} else {
		enum UV__DT_CHAR = -6;
	}
	static if (__traits(compiles, { auto v = DT_BLK; })) {
		alias UV__DT_BLOCK = DT_BLK;
	} else {
		enum UV__DT_BLOCK = -7;
	}
}

///
struct uv_lib_t {
	///
	void* handle;
	///
	char* errmsg;
}

mixin template UV_LOOP_PRIVATE_FIELDS() {
	c_ulong flags;
	int backend_fd;
	void*[2] pending_queue;
	void*[2] watcher_queue;
	uv__io_t** watchers;
	uint nwatchers;
	uint nfds;
	void*[2] wq;
	uv_mutex_t wq_mutex;
	uv_async_t wq_async;
	uv_rwlock_t cloexec_lock;
	uv_handle_t* closing_handles;
	void*[2] process_handles;
	void*[2] prepare_handles;
	void*[2] check_handles;
	void*[2] idle_handles;
	void*[2] async_handles;
	uv__async async_watcher;
	struct Timer_heap {
		void* min;
		uint nelts;
	}
	Timer_heap timer_heap;
	ulong timer_counter;
	ulong time;
	int[2] signal_pipefd;
	uv__io_t signal_io_watcher;
	uv_signal_t child_watcher;
	int emfile_fd;
	mixin UV_PLATFORM_LOOP_FIELDS;
}

mixin template UV_REQ_TYPE_PRIVATE() { /* empty */ }

mixin template UV_REQ_PRIVATE_FIELDS() { /* empty */ }

mixin template UV_PRIVATE_REQ_TYPES() { /* empty */ }

mixin template UV_WRITE_PRIVATE_FIELDS() {
	void*[2] queue;
	uint write_index;
	uv_buf_t* bufs;
	uint nbufs;
	int error;
	uv_buf_t[4] bufsml;
}

mixin template UV_CONNECT_PRIVATE_FIELDS() {
	void*[2] queue;
}

mixin template UV_SHUTDOWN_PRIVATE_FIELDS() { /* empty */ }

mixin template UV_UDP_SEND_PRIVATE_FIELDS() {
	void*[2] queue;
	sockaddr_storage addr;
	uint nbufs;
	uv_buf_t* bufs;
	ssize_t status;
	uv_udp_send_cb send_cb;
	uv_buf_t[4] bufsml;
}

mixin template UV_HANDLE_PRIVATE_FIELDS() {
	uv_handle_t* next_closing;
	uint flags;
}

mixin template UV_STREAM_PRIVATE_FIELDS() {
	uv_connect_t *connect_req;
	uv_shutdown_t *shutdown_req;
	uv__io_t io_watcher;
	void*[2] write_queue;
	void*[2] write_completed_queue;
	uv_connection_cb connection_cb;
	int delayed_error;
	int accepted_fd;
	void* queued_fds;
	mixin UV_STREAM_PRIVATE_PLATFORM_FIELDS;
}

mixin template UV_TCP_PRIVATE_FIELDS() { /* empty */ }

mixin template UV_UDP_PRIVATE_FIELDS() {
	uv_alloc_cb alloc_cb;
	uv_udp_recv_cb recv_cb;
	uv__io_t io_watcher;
	void*[2] write_queue;
	void*[2] write_completed_queue;
}

mixin template UV_PIPE_PRIVATE_FIELDS() {
	const char* pipe_fname; /* strdup'ed */
}

mixin template UV_POLL_PRIVATE_FIELDS() {
	uv__io_t io_watcher;
}

mixin template UV_PREPARE_PRIVATE_FIELDS() {
	uv_prepare_cb prepare_cb;
	void*[2] queue;
}

mixin template UV_CHECK_PRIVATE_FIELDS() {
	uv_check_cb check_cb;
	void*[2] queue;
}

mixin template UV_IDLE_PRIVATE_FIELDS() {
	uv_idle_cb idle_cb;
	void*[2] queue;
}

mixin template UV_ASYNC_PRIVATE_FIELDS() {
	uv_async_cb async_cb;
	void*[2] queue;
	int pending;
}

mixin template UV_TIMER_PRIVATE_FIELDS() {
	uv_timer_cb timer_cb;
	void*[3] heap_node;
	ulong timeout;
	ulong repeat;
	ulong start_id;
}

mixin template UV_GETADDRINFO_PRIVATE_FIELDS() {
	uv__work work_req;
	uv_getaddrinfo_cb cb;
	addrinfo* hints;
	char* hostname;
	char* service;
	addrinfo* addrinfo;
	int retcode;
}

mixin template UV_GETNAMEINFO_PRIVATE_FIELDS() {
	uv__work work_req;
	uv_getnameinfo_cb getnameinfo_cb;
	sockaddr_storage storage;
	int flags;
	char[NI_MAXHOST] host; 
	char[NI_MAXSERV] service;
	int retcode;
}

mixin template UV_PROCESS_PRIVATE_FIELDS() {
	void*[2] queue;
	int status;
}

mixin template UV_FS_PRIVATE_FIELDS() {
	const char *new_path;
	uv_file file;
	int flags;
	mode_t mode;
	uint nbufs;
	uv_buf_t* bufs;
	off_t off;
	uv_uid_t uid;
	uv_gid_t gid;
	double atime;
	double mtime;
	uv__work work_req;
	uv_buf_t[4] bufsml;
}

mixin template UV_WORK_PRIVATE_FIELDS() {
	uv__work work_req;
}

mixin template UV_TTY_PRIVATE_FIELDS() {
	termios orig_termios;
	int mode;
}

mixin template UV_SIGNAL_PRIVATE_FIELDS() {
	/* RB_ENTRY(uv_signal_s) tree_entry; */
	struct Tree_entry {
		uv_signal_s* rbe_left;
		uv_signal_s* rbe_right;
		uv_signal_s* rbe_parent;
		int rbe_color;
	}
	Tree_entry tree_entry;
	/* Use two counters here so we don have to fiddle with atomics. */
	uint caught_signals;
	uint dispatched_signals;
}

mixin template UV_FS_EVENT_PRIVATE_FIELDS() {
	uv_fs_event_cb cb;
	mixin UV_PLATFORM_FS_EVENT_FIELDS;
}