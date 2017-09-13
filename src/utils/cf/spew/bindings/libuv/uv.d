/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
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
module cf.spew.bindings.libuv.uv;
import core.stdc.config;
import core.stdc.stdio;

import cf.spew.bindings.libuv.uv_win;
import cf.spew.bindings.libuv.uv_unix;

__gshared nothrow @nogc @system extern(C):

///
enum uv_errno_t {
	///
	UV_E2BIG = "argument list too long",
	///
	UV_EACCES = "permission denied",
	///
	UV_EADDRINUSE = "address already in use",
	///
	UV_EADDRNOTAVAIL = "address not available",
	///
	UV_EAFNOSUPPORT = "address family not supported",
	///
	UV_EAGAIN = "resource temporarily unavailable",
	///
	UV_EAI_ADDRFAMILY = "address family not supported",
	///
	UV_EAI_AGAIN = "temporary failure",
	///
	UV_EAI_BADFLAGS = "bad ai_flags value",
	///
	UV_EAI_BADHINTS = "invalid value for hints",
	///
	UV_EAI_CANCELED = "request canceled",
	///
	UV_EAI_FAIL = "permanent failure",
	///
	UV_EAI_FAMILY = "ai_family not supported",
	///
	UV_EAI_MEMORY = "out of memory",
	///
	UV_EAI_NODATA = "no address",
	///
	UV_EAI_NONAME = "unknown node or service",
	///
	UV_EAI_OVERFLOW = "argument buffer overflow",
	///
	UV_EAI_PROTOCOL = "resolved protocol is unknown",
	///
	UV_EAI_SERVICE = "service not available for socket type",
	///
	UV_EAI_SOCKTYPE = "socket type not supported",
	///
	UV_EALREADY = "connection already in progress",
	///
	UV_EBADF = "bad file descriptor",
	///
	UV_EBUSY = "resource busy or locked",
	///
	UV_ECANCELED = "operation canceled",
	///
	UV_ECHARSET = "invalid Unicode character",
	///
	UV_ECONNABORTED = "software caused connection abort",
	///
	UV_ECONNREFUSED = "connection refused",
	///
	UV_ECONNRESET = "connection reset by peer",
	///
	UV_EDESTADDRREQ = "destination address required",
	///
	UV_EEXIST = "file already exists",
	///
	UV_EFAULT = "bad address in system call argument",
	///
	UV_EFBIG = "file too large",
	///
	UV_EHOSTUNREACH = "host is unreachable",
	///
	UV_EINTR = "interrupted system call",
	///
	UV_EINVAL = "invalid argument",
	///
	UV_EIO = "i/o error",
	///
	EISCONN = "socket is already connected",
	///
	UV_EISDIR = "illegal operation on a directory",
	///
	UV_ELOOP = "too many symbolic links encountered",
	///
	UV_EMFILE = "too many open files",
	///
	UV_EMSGSIZE = "message too long",
	///
	UV_ENAMETOOLONG = "name too long",
	///
	UV_ENETDOWN = "network is down",
	///
	UV_ENETUNREACH = "network is unreachable",
	///
	UV_ENFILE = "file table overflow",
	///
	UV_ENOBUFS = "no buffer space available",
	///
	UV_ENODEV = "no such device",
	///
	UV_ENOENT = "no such file or directory",
	///
	UV_ENOMEM = "not enough memory",
	///
	UV_ENONET = "machine is not on the network",
	///
	UV_ENOPROTOOPT = "protocol not available",
	///
	UV_ENOSPC = "no space left on device",
	///
	UV_ENOSYS = "function not implemented",
	///
	UV_ENOTCONN = "socket is not connected",
	///
	UV_ENOTDIR = "not a directory",
	///
	UV_ENOTEMPTY = "directory not empty",
	///
	UV_ENOTSOCK = "socket operation on non-socket",
	///
	UV_ENOTSUP = "operation not supported on socket",
	///
	UV_EPERM = "operation not permitted",
	///
	UV_EPIPE = "broken pipe",
	///
	UV_EPROTO = "protocol error",
	///
	UV_EPROTONOSUPPORT = "protocol not supported",
	///
	UV_EPROTOTYPE = "protocol wrong type for socket",
	///
	UV_ERANGE = "result too large",
	///
	UV_EROFS = "read-only file system",
	///
	UV_ESHUTDOWN = "cannot send after transport endpoint shutdown",
	///
	UV_ESPIPE = "invalid seek",
	///
	UV_ESRCH = "no such process",
	///
	UV_ETIMEDOUT = "connection timed out",
	///
	UV_ETXTBSY = "text file is busy",
	///
	UV_EXDEV = "cross-device link not permitted",
	///
	UV_UNKNOWN = "unknown error",
	///
	UV_EOF = "end of file",
	///
	UV_ENXIO = "no such device or address",
	///
	UV_EMLINK = "too many links",
	///
	UV_EHOSTDOWN = "host is down",
	///
	UV_EREMOTEIO = "remote I/O error",
}

///
enum uv_handle_type {
	///
	UV_UNKNOWN_HANDLE = 0,

	///
	UV_ASYNC,
	///
	UV_CHECK,
	///
	UV_FS_EVENT,
	///
	UV_FS_POLL,
	///
	UV_HANDLE,
	///
	UV_IDLE,
	///
	UV_NAMED_PIPE,
	///
	UV_POLL,
	///
	UV_PREPARE,
	///
	UV_PROCESS,
	///
	UV_STREAM,
	///
	UV_TCP,
	///
	UV_TIMER,
	///
	UV_TTY,
	///
	UV_UDP,
	///
	UV_SIGNAL,
	///
	UV_FILE,

	///
	UV_HANDLE_TYPE_MAX
}

///
mixin(`enum uv_req_type {
	///
	UV_UNKNOWN_REQ = 0,

	///
	UV_REQ,
	///
	UV_CONNECT,
	///
	UV_WRITE,
	///
	UV_SHUTDOWN,
	///
	UV_UDP_SEND,
	///
	UV_FS,
	///
	UV_WORK,
	///
	UV_GETADDRINFO,
	///
	UV_GETNAMEINFO,
` ~ UV_REQ_TYPE_PRIVATE ~ `
	///
	UV_REQ_TYPE_MAX
}`);

/// Handle types.
alias
	///
	uv_loop_t = uv_loop_s,
	///
	uv_handle_t = uv_handle_s,
	///
	uv_stream_t = uv_stream_s,
	///
	uv_tcp_t = uv_tcp_s,
	///
	uv_udp_t = uv_udp_s,
	///
	uv_pipe_t = uv_pipe_s,
	///
	uv_tty_t = uv_tty_s,
	///
	uv_poll_t = uv_poll_s,
	///
	uv_timer_t = uv_timer_s,
	///
	uv_prepare_t = uv_prepare_s,
	///
	uv_check_t = uv_check_s,
	///
	uv_idle_t = uv_idle_s,
	///
	uv_async_t = uv_async_s,
	///
	uv_process_t = uv_process_s,
	///
	uv_fs_event_t = uv_fs_event_s,
	///
	uv_fs_poll_t = uv_fs_poll_s,
	///
	uv_signal_t = uv_signal_s;

/// Request types.
alias 
	///
	uv_req_t = uv_req_s,
	///
	uv_getaddrinfo_t = uv_getaddrinfo_s,
	///
	uv_getnameinfo_t = uv_getnameinfo_s,
	///
	uv_shutdown_t = uv_shutdown_s,
	///
	uv_write_t = uv_write_s,
	///
	uv_connect_t = uv_connect_s,
	///
	uv_udp_send_t = uv_udp_send_s,
	///
	uv_fs_t = uv_fs_s,
	///
	uv_work_t = uv_work_s;

/// None of the above.
alias
	///
	uv_cpu_info_t = uv_cpu_info_s,
	///
	uv_interface_address_t = uv_interface_address_s,
	///
	uv_dirent_t = uv_dirent_s,
	///
	uv_passwd_t = uv_passwd_s;

///
enum uv_loop_option {
	///
	UV_LOOP_BLOCK_SIGNAL
}

///
enum uv_run_mode {
	///
	UV_RUN_DEFAULT = 0,
	///
	UV_RUN_ONCE,
	///
	UV_RUN_NOWAIT
}

///
uint function() uv_version;
///
const(char)* function() uv_version_string;

///
alias
	///
	uv_malloc_func = void* function(size_t size),
	///
	uv_realloc_func = void* function(void* ptr, size_t size),
	///
	uv_calloc_func = void* function(size_t count, size_t size),
	///
	uv_free_func = void function(void* ptr);

///
int function(uv_malloc_func malloc_func, uv_realloc_func realloc_func, uv_calloc_func calloc_func, uv_free_func free_func) uv_replace_allocator;

///
uv_loop_t* function() uv_default_loop;
///
int function(uv_loop_t* loop) uv_loop_init;
///
int function(uv_loop_t* loop) uv_loop_close;

///
size_t function() uv_loop_size;
///
int function(const(uv_loop_t)* loop) uv_loop_alive;
///
int function(uv_loop_t* loop, uv_loop_option option, ...) uv_loop_configure;
///
int function(uv_loop_t* loop) uv_loop_fork;
///
int function(uv_loop_t*, uv_run_mode mode) uv_run;
///
void function(uv_loop_t*) uv_stop;

///
void function(uv_handle_t*) uv_ref;
///
void function(uv_handle_t*) uv_unref;
///
int function(const(uv_handle_t)*) uv_has_ref;

///
void function(uv_loop_t*) uv_update_time;
///
ulong function(const(uv_loop_t)*) uv_now;

///
int function(const(uv_loop_t)*) uv_backend_fd;
///
int function(const(uv_loop_t)*) uv_backend_timeout;

///
alias
	///
	uv_alloc_cb = void function(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf),
	///
	uv_read_cb = void function(uv_stream_t* stream, ptrdiff_t nread, const(uv_buf_t)* buf),
	///
	uv_write_cb = void function(uv_write_t* req, int status),
	///
	uv_connect_cb = void function(uv_connect_t* req, int status),
	///
	uv_shutdown_cb = void function(uv_shutdown_t* req, int status),
	///
	uv_connection_cb = void function(uv_connect_t* req, int status),
	///
	uv_close_cb = void function(uv_handle_t* req, int status),
	///
	uv_poll_cb = void function(uv_poll_t* handle, int status, int events),
	///
	uv_timer_cb = void function(uv_timer_t* handle),
	///
	uv_async_cb = void function(uv_async_t* handle),
	///
	uv_prepare_cb = void function(uv_prepare_t* handle),
	///
	uv_check_cb = void function(uv_check_t* handle),
	///
	uv_idle_cb = void function(uv_idle_t* handle),
	///
	uv_exit_cb = void function(uv_process_t*, long exit_status, int term_signal),
	///
	uv_walk_cb = void function(uv_handle_t* handle, void* arg),
	///
	uv_fs_cb = void function(uv_fs_t* req),
	///
	uv_work_cb = void function(uv_work_t* req),
	///
	uv_after_work_cb = void function(uv_work_t* req, int status),
	///
	uv_getaddrinfo_cb = void function(uv_getaddrinfo_t* req, int status, addrinfo* res),
	///
	uv_getnameinfo_cb = void function(uv_getnameinfo_t* req, int status, const(char)* hostname, const(char)* service);

///
struct uv_timespec_t {
	///
	c_long tv_sec;
	///
	c_long tv_nsec;
}

///
struct uv_stat_t {
	///
	ulong st_dev;
	///
	ulong st_mode;
	///
	ulong st_nlink;
	///
	ulong st_uid;
	///
	ulong st_gid;
	///
	ulong st_rdev;
	///
	ulong st_ino;
	///
	ulong st_size;
	///
	ulong st_blksize;
	///
	ulong st_blocks;
	///
	ulong st_flags;
	///
	ulong st_gen;
	///
	uv_timespec_t st_atim;
	///
	uv_timespec_t st_mtim;
	///
	uv_timespec_t st_ctim;
	///
	uv_timespec_t st_birthtim;
}

///
alias
	///
	uv_fs_event_cb = void function(uv_fs_event_t* handle, const(char)* filename, int events, int status),
	///
	uv_fs_poll_cb = void function(uv_fs_poll_t* handle, int status, const(uv_stat_t)* prev, const(uv_stat_t)* curr),
	///
	uv_signal_cb = void function(uv_signal_t* handle, int signum);

///
enum uv_membership {
	///
	UV_LEAVE_GROUP = 0,
	///
	UV_JOIN_GROUP
}

///
int function(int sys_errno) uv_translate_sys_error;
///
const(char)* function(int err) uv_strerror;
///
const(char)* function(int err) uv_err_name;

///
mixin template UV_REQ_FIELDS() {
	/// public
	void* data;
	/// read-only
	uv_req_type type;
	/// private
	void*[2] active_queue;
	/// Ditto
	void*[4] reserved;
	/// Ditto
	mixin UV_REQ_PRIVATE_FIELDS;
}

///
struct uv_req_s {
	///
	mixin UV_REQ_FIELDS;
}

/// Platform-specific request types.
mixin UV_PRIVATE_REQ_TYPES;

///
int function(uv_shutdown_t* req, uv_stream_t* handle, uv_shutdown_cb cb) uv_shutdown;

///
struct uv_shutdown_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_stream_t* handle;
	///
	uv_shutdown_cb cb;
	///
	mixin UV_SHUTDOWN_PRIVATE_FIELDS;
}

mixin template UV_HANDLE_FIELDS() {
	/// public
	void* data;
	/// read-only
	uv_loop_t* loop;
	uv_handle_type type;
	/// private
	uv_close_cb close_cb;
	/// Ditto
	void*[2] handle_queue;

	/// Ditto
	union U {
		///
		int fd;
		///
		void*[4] reserved;
	}
	/// Ditto
	U u;
	/// Ditto
	mixin UV_HANDLE_PRIVATE_FIELDS;
}

/// The abstract base class of all handles
struct uv_handle_s {
	///
	mixin UV_HANDLE_FIELDS;
}

///
size_t function(uv_handle_type type) uv_handle_size;
///
size_t function(uv_req_type type) uv_req_size;

///
int function(const(uv_handle_t)* handle) uv_is_active;

///
void function(uv_loop_t* loop, uv_walk_cb walk_cb, void* arg) uv_walk;

/// Helpers for ad hoc debugging, no API/ABI stability guaranteed.
void function(uv_loop_t* loop, FILE* stream) uv_print_all_handles;
///
void function(uv_loop_t* loop, FILE* stream) uv_print_active_handles;

///
void function(uv_handle_t* handle, uv_close_cb close_cb) uv_close;

///
int function(uv_handle_t* handle, int* value) uv_send_buffer_size;
///
int function(uv_handle_t* handle, int* value) uv_recv_buffer_size;

///
int function(const(uv_handle_t)* handle, uv_os_fd_t* fd) uv_fileno;

///
uv_buf_t function(char* base, uint len) uv_buf_init;

///
mixin template UV_STREAM_FIELDS() {
	/// number of bytes queued for writing
	size_t write_queue_size;
	///
	uv_alloc_cb alloc_cb;
	///
	uv_read_cb read_cb;
	/// private
	mixin UV_STREAM_PRIVATE_FIELDS;
}

/**
 * uv_stream_t is a subclass of uv_handle_t.
 *
 * uv_stream is an abstract class.
 *
 * uv_stream_t is the parent class of uv_tcp_t, uv_pipe_t and uv_tty_t.
 */
struct uv_stream_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_STREAM_FIELDS;
}

///
int function(uv_stream_t* stream, int backlog, uv_connection_cb cb) uv_listen;
///
int function(uv_stream_t* server, uv_stream_t* client) uv_accept;

///
int function(uv_stream_t*, uv_alloc_cb alloc_cb, uv_read_cb read_cb) uv_read_start;
///
int function(uv_stream_t*) uv_read_stop;

///
int function(uv_write_t* req, uv_stream_t* handle, const(uv_buf_t)[] bufs, uint nbufs, uv_write_cb cb) uv_write;
///
int function(uv_write_t* req, uv_stream_t* handle, const(uv_buf_t)[] bufs, uint nbufs, uv_stream_t* send_handle, uv_write_cb cb) uv_write2;
///
int function(uv_stream_t* handle, const(uv_buf_t)[] bufs, uint nbufs) uv_try_write;

/// uv_write_t is a subclass of uv_req_t.
struct uv_write_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_write_cb cb;
	///
	uv_stream_t* send_handle;
	///
	uv_stream_t* handle;
	///
	mixin UV_WRITE_PRIVATE_FIELDS;
}

///
int function(const(uv_stream_t)* handle) uv_is_readable;
///
int function(const(uv_stream_t)* handle) uv_is_writable;

///
int function(uv_stream_t* handle, int blocking) uv_stream_set_blocking;

///
int function(const(uv_handle_t)* handle) uv_is_closing;

/**
 * uv_tcp_t is a subclass of uv_stream_t.
 *
 * Represents a TCP stream or TCP server.
 */
struct uv_tcp_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_STREAM_FIELDS;
	///
	mixin UV_TCP_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_tcp_t* handle) uv_tcp_init;
///
int function(uv_loop_t*, uv_tcp_t* handle, uint flags) uv_tcp_init_ex;
///
int function(uv_tcp_t* handle, uv_os_sock_t sock) uv_tcp_open;
///
int function(uv_tcp_t* handle, int enable) uv_tcp_nodelay;
///
int function(uv_tcp_t* handle, int enable, uint delay) uv_tcp_keepalive;
///
int function(uv_tcp_t* handle, int enable) uv_tcp_simultaneous_accepts;

///
enum uv_tcp_flags {
	/// Used with uv_tcp_bind, when an IPv6 address is used.
	UV_TCP_IPV6ONLY = 1
}

///
int function(uv_tcp_t* handle, const(sockaddr)* addr, uint flags) uv_tcp_bind;
///
int function(const(uv_tcp_t)* handle, sockaddr* name, int* namelen) uv_tcp_getsockname;
///
int function(const(uv_tcp_t)* handle, sockaddr* name, int* namelen) uv_tcp_getpeername;
///
int function(uv_connect_t* req, uv_tcp_t* handle, const(sockaddr)* addr, uv_connect_cb cb) uv_tcp_connect;

/// uv_connect_t is a subclass of uv_req_t.
struct uv_connect_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_connect_cb cb;
	///
	uv_stream_t* handle;
	///
	mixin UV_CONNECT_PRIVATE_FIELDS;
}

/**
 * UDP support.
 */
enum uv_udp_flags {
	/// Disables dual stack mode.
	UV_UDP_IPV6ONLY = 1,
	/**
	 * Indicates message was truncated because read buffer was too small. The
	 * remainder was discarded by the OS. Used in uv_udp_recv_cb.
	 */
	UV_UDP_PARTIAL = 2,
	/**
	 * Indicates if SO_REUSEADDR will be set when binding the handle.
	 * This sets the SO_REUSEPORT socket flag on the BSDs and OS X. On other
	 * Unix platforms, it sets the SO_REUSEADDR flag.  What that means is that
	 * multiple threads or processes can bind to the same address without error
	 * (provided they all set the flag) but only the last one to bind will receive
	 * any traffic, in effect "stealing" the port from the previous listener.
	 */
	UV_UDP_REUSEADDR = 4
}

///
alias
	///
	uv_udp_send_cb = void function(uv_udp_send_t* req, int status),
	///
	uv_udp_recv_cb = void function(uv_udp_t* handle, ptrdiff_t nread, const(uv_buf_t)* buf, const(sockaddr)* addr, uint flags);

/// uv_udp_t is a subclass of uv_handle_t.
struct uv_udp_s {
	///
	mixin UV_HANDLE_FIELDS;
	/**
	 * read-only
	 * Number of bytes queued for sending. This field strictly shows how much
	 * information is currently queued.
	 */
	size_t send_queue_size;
	/**
	 * Number of send requests currently in the queue awaiting to be processed.
	 */
	size_t send_queue_count;
	///
	mixin UV_UDP_PRIVATE_FIELDS;
}

/// uv_udp_send_t is a subclass of uv_req_t.
struct uv_udp_send_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_udp_t* handle;
	///
	uv_udp_send_cb cb;
	///
	mixin UV_UDP_SEND_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_udp_t* handle) uv_udp_init;
///
int function(uv_loop_t*, uv_udp_t* handle, uint flags) uv_udp_init_ex;
///
int function(uv_udp_t* handle, uv_os_sock_t sock) uv_udp_open;
///
int function(uv_udp_t* handle, const(sockaddr)* addr, uint flags) uv_udp_bind;

///
int function(const(uv_udp_t)* handle, sockaddr* name, int* namelen) uv_udp_getsockname;
///
int function(uv_udp_t* handle, const(char)* multicast_addr, const(char)* interface_addr, uv_membership membership) uv_udp_set_membership;
///
int function(uv_udp_t* handle, int on) uv_udp_set_multicast_loop;
///
int function(uv_udp_t* handle, int ttl) uv_udp_set_multicast_ttl;
///
int function(uv_udp_t* handle, const(char)* interface_addr) uv_udp_set_multicast_interface;
///
int function(uv_udp_t* handle, int on) uv_udp_set_broadcast;
///
int function(uv_udp_t* handle, int ttl) uv_udp_set_ttl;
///
int function(uv_udp_send_t* req, uv_udp_t* handle, const(uv_buf_t)[] bufs, uint nbufs, const(sockaddr)* addr, uv_udp_send_cb send_cb) uv_udp_send;
///
int function(uv_udp_t* handle, const(uv_buf_t)[] bufs, uint nbufs, const(sockaddr)* addr) uv_udp_try_send;
///
int function(uv_udp_t* handle, uv_alloc_cb alloc_cb, uv_udp_recv_cb recv_cb) uv_udp_recv_start;
///
int function(uv_udp_t* handle) uv_udp_recv_stop;

/**
 * uv_tty_t is a subclass of uv_stream_t.
 *
 * Representing a stream for the console.
 */
struct uv_tty_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_STREAM_FIELDS;
	///
	mixin UV_TTY_PRIVATE_FIELDS;
}

///
enum uv_tty_mode_t {
	/// Initial/normal terminal mode
	UV_TTY_MODE_NORMAL,
	/// Raw input mode (On Windows, ENABLE_WINDOW_INPUT is also enabled)
	UV_TTY_MODE_RAW,
	/// Binary-safe I/O mode for IPC (Unix-only)
	UV_TTY_MODE_IO
}

///
int function(uv_loop_t*, uv_tty_t*, uv_file fd, int readable) uv_tty_init;
///
int function(uv_tty_t*, uv_tty_mode_t mode) uv_tty_set_mode;
///
int function() uv_tty_reset_mode;
///
int function(uv_tty_t*, int* width, int* height) uv_tty_get_winsize;

///
uv_handle_type function(uv_file file) uv_guess_handle;

/**
 * uv_pipe_t is a subclass of uv_stream_t.
 *
 * Representing a pipe stream or pipe server. On Windows this is a Named
 * Pipe. On Unix this is a Unix domain socket.
 */
struct uv_pipe_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_STREAM_FIELDS;
	/// non-zero if this pipe is used for passing handles
	int ipc;
	///
	mixin UV_PIPE_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_pipe_t* handle, int ipc) uv_pipe_init;
///
int function(uv_pipe_t*, uv_file file) uv_pipe_open;
///
int function(uv_pipe_t* handle, const(char)* name) uv_pipe_bind;
///
void function(uv_connect_t* req, uv_pipe_t* handle, const(char)* name, uv_connect_cb cb) uv_pipe_connect;
///
int function(const(uv_pipe_t)* handle, char* buffer, size_t* size) uv_pipe_getsockname;
///
int function(const(uv_pipe_t)* handle, char* buffer, size_t* size) uv_pipe_getpeername;
///
void function(uv_pipe_t* handle, int count) uv_pipe_pending_instances;
///
int function(uv_pipe_t* handle) uv_pipe_pending_count;
///
uv_handle_type function(uv_pipe_t* handle) uv_pipe_pending_type;

///
struct uv_poll_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	uv_poll_cb poll_cb;
	///
	mixin UV_POLL_PRIVATE_FIELDS;
}

///
enum uv_poll_event {
	///
	UV_READABLE = 1,
	///
	UV_WRITABLE = 2,
	///
	UV_DISCONNECT = 4,
	///
	UV_PRIORITIZED = 8
}

///
int function(uv_loop_t* loop, uv_poll_t* handle, int fd) uv_poll_init;
///
int function(uv_loop_t* loop, uv_poll_t* handle, uv_os_sock_t socket) uv_poll_init_socket;
///
int function(uv_poll_t* handle, int events, uv_poll_cb cb) uv_poll_start;
///
int function(uv_poll_t* handle) uv_poll_stop;

///
struct uv_prepare_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_PREPARE_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_prepare_t* prepare) uv_prepare_init;
///
int function(uv_prepare_t* prepare, uv_prepare_cb cb) uv_prepare_start;
///
int function(uv_prepare_t* prepare) uv_prepare_stop;

///
struct uv_check_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_CHECK_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_check_t* check) uv_check_init;
///
int function(uv_check_t* check, uv_check_cb cb) uv_check_start;
///
int function(uv_check_t* check) uv_check_stop;

///
struct uv_idle_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_IDLE_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_idle_t* idle) uv_idle_init;
///
int function(uv_idle_t* idle, uv_idle_cb cb) uv_idle_start;
///
int function(uv_idle_t* idle) uv_idle_stop;

///
struct uv_async_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_ASYNC_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_async_t* async, uv_async_cb async_cb) uv_async_init;
///
int function(uv_async_t* async) uv_async_send;

/**
 * uv_timer_t is a subclass of uv_handle_t.
 *
 * Used to get woken up at a specified time in the future.
 */
struct uv_timer_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	mixin UV_TIMER_PRIVATE_FIELDS;
}

///
int function(uv_loop_t*, uv_timer_t* handle) uv_timer_init;
///
int function(uv_timer_t* handle, uv_timer_cb cb, ulong timeout, ulong repeat) uv_timer_start;
///
int function(uv_timer_t* handle) uv_timer_stop;
///
int function(uv_timer_t* handle) uv_timer_again;
///
void function(uv_timer_t* handle, ulong repeat) uv_timer_set_repeat;
///
ulong function(const uv_timer_t* handle) uv_timer_get_repeat;

/**
 * uv_getaddrinfo_t is a subclass of uv_req_t.
 *
 * Request object for uv_getaddrinfo.
 */
struct uv_getaddrinfo_s {
	///
	mixin UV_REQ_FIELDS;
	/// read-only
	uv_loop_t* loop;
	/// struct addrinfo* addrinfo is marked as private, but it really isn't.
	mixin UV_GETADDRINFO_PRIVATE_FIELDS;
}

///
int function(uv_loop_t* loop, uv_getaddrinfo_t* req, uv_getaddrinfo_cb getaddrinfo_cb, const(char)* node, const(char)* service, const(addrinfo)* hints) uv_getaddrinfo;
///
void function(addrinfo* ai) uv_freeaddrinfo;

/**
 * uv_getnameinfo_t is a subclass of uv_req_t.
 *
 * Request object for uv_getnameinfo.
 */
struct uv_getnameinfo_s {
	///
	mixin UV_REQ_FIELDS;
	/// read-only
	uv_loop_t* loop;
	/// host and service are marked as private, but they really aren't.
	mixin UV_GETNAMEINFO_PRIVATE_FIELDS;
}

///
int function(uv_loop_t* loop, uv_getnameinfo_t* req, uv_getnameinfo_cb getnameinfo_cb, const(sockaddr)* addr, int flags) uv_getnameinfo;

/// uv_spawn() options.
enum uv_stdio_flags {
	///
	UV_IGNORE = 0x00,
	///
	UV_CREATE_PIPE = 0x01,
	///
	UV_INHERIT_FD = 0x02,
	///
	UV_INHERIT_STREAM = 0x04,
	
	/**
	 * When UV_CREATE_PIPE is specified, UV_READABLE_PIPE and UV_WRITABLE_PIPE
	 * determine the direction of flow, from the child process' perspective. Both
	 * flags may be specified to create a duplex data stream.
	 */
	UV_READABLE_PIPE  = 0x10,
	///
	UV_WRITABLE_PIPE  = 0x20
}

///
struct uv_stdio_container_s {
	///
	uv_stdio_flags flags;
	
	///
	union Data {
		///
		uv_stream_t* stream;
		///
		int fd;
	}
	///
	Data data;
}

///
alias uv_stdio_container_t = uv_stdio_container_s;

///
struct uv_process_options_s {
	/// Called after the process exits.
	uv_exit_cb exit_cb;
	/// Path to program to execute.
	const char* file;
	/**
	 * Command line arguments. args[0] should be the path to the program. On
	 * Windows this uses CreateProcess which concatenates the arguments into a
	 * string this can cause some strange errors. See the note at
	 * windows_verbatim_arguments.
	 */
	char** args;
	/**
	 * This will be set as the environ variable in the subprocess. If this is
	 * NULL then the parents environ will be used.
	 */
	char** env;
	/**
	 * If non-null this represents a directory the subprocess should execute
	 * in. Stands for current working directory.
	 */
	const(char)* cwd;
	/**
	 * Various flags that control how uv_spawn() behaves. See the definition of
	 * `enum uv_process_flags` below.
	 */
	uint flags;
	/**
	 * The `stdio` field points to an array of uv_stdio_container_t structs that
	 * describe the file descriptors that will be made available to the child
	 * process. The convention is that stdio[0] points to stdin, fd 1 is used for
	 * stdout, and fd 2 is stderr.
	 *
	 * Note that on windows file descriptors greater than 2 are available to the
	 * child process only if the child processes uses the MSVCRT runtime.
	 */
	int stdio_count;
	///
	uv_stdio_container_t* stdio;
	/**
	 * Libuv can change the child process' user/group id. This happens only when
	 * the appropriate bits are set in the flags fields. This is not supported on
	 * windows; uv_spawn() will fail and set the error to UV_ENOTSUP.
	 */
	uv_uid_t uid;
	///
	uv_gid_t gid;
}
////
alias uv_process_options_t = uv_process_options_s;

/**
 * These are the flags that can be used for the uv_process_options.flags field.
 */
enum uv_process_flags {
	/**
	 * Set the child process' user id. The user id is supplied in the `uid` field
	 * of the options struct. This does not work on windows; setting this flag
	 * will cause uv_spawn() to fail.
	 */
	UV_PROCESS_SETUID = (1 << 0),
	/**
	 * Set the child process' group id. The user id is supplied in the `gid`
	 * field of the options struct. This does not work on windows; setting this
	 * flag will cause uv_spawn() to fail.
	 */
	UV_PROCESS_SETGID = (1 << 1),
	/**
	 * Do not wrap any arguments in quotes, or perform any other escaping, when
	 * converting the argument list into a command line string. This option is
	 * only meaningful on Windows systems. On Unix it is silently ignored.
	 */
	UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS = (1 << 2),
	/**
	 * Spawn the child process in a detached state - this will make it a process
	 * group leader, and will effectively enable the child to keep running after
	 * the parent exits.  Note that the child process will still keep the
	 * parent's event loop alive unless the parent process calls uv_unref() on
	 * the child's process handle.
	 */
	UV_PROCESS_DETACHED = (1 << 3),
	/**
	 * Hide the subprocess console window that would normally be created. This
	 * option is only meaningful on Windows systems. On Unix it is silently
	 * ignored.
	 */
	UV_PROCESS_WINDOWS_HIDE = (1 << 4)
}

/**
 * uv_process_t is a subclass of uv_handle_t.
 */
struct uv_process_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	uv_exit_cb exit_cb;
	///
	int pid;
	///
	mixin UV_PROCESS_PRIVATE_FIELDS;
}

///
int function(uv_loop_t* loop, uv_process_t* handle, const(uv_process_options_t)* options) uv_spawn;
///
int function(uv_process_t*, int signum) uv_process_kill;
///
int function(int pid, int signum) uv_kill;


/**
 * uv_work_t is a subclass of uv_req_t.
 */
struct uv_work_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_loop_t* loop;
	///
	uv_work_cb work_cb;
	///
	uv_after_work_cb after_work_cb;
	///
	mixin UV_WORK_PRIVATE_FIELDS;
}

///
int function(uv_loop_t* loop, uv_work_t* req, uv_work_cb work_cb, uv_after_work_cb after_work_cb) uv_queue_work;
///
int function(uv_req_t* req) uv_cancel;


///
struct uv_cpu_info_s {
	///
	char* model;
	///
	int speed;
	///
	struct uv_cpu_times_s {
		///
		ulong user;
		///
		ulong nice;
		///
		ulong sys;
		///
		ulong idle;
		///
		ulong irq;
	}
	///
	uv_cpu_times_s cpu_times;
}

///
struct uv_interface_address_s {
	///
	char* name;
	///
	char[6] phys_addr;
	///
	int is_internal;
	///
	union Address {
		///
		sockaddr_in address4;
		///
		sockaddr_in6 address6;
	}
	///
	Address address;
	///
	union Netmask {
		///
		sockaddr_in netmask4;
		///
		sockaddr_in6 netmask6;
	}
	///
	Netmask netmask;
}

///
struct uv_passwd_s {
	///
	char* username;
	///
	c_long uid;
	///
	c_long gid;
	///
	char* shell;
	///
	char* homedir;
}

///
enum uv_dirent_type_t {
	///
	UV_DIRENT_UNKNOWN,
	///
	UV_DIRENT_FILE,
	///
	UV_DIRENT_DIR,
	///
	UV_DIRENT_LINK,
	///
	UV_DIRENT_FIFO,
	///
	UV_DIRENT_SOCKET,
	///
	UV_DIRENT_CHAR,
	///
	UV_DIRENT_BLOCK
}

///
struct uv_dirent_s {
	///
	const(char)* name;
	///
	uv_dirent_type_t type;
}

///
char** function(int argc, char** argv) uv_setup_args;
///
int function(char* buffer, size_t size) uv_get_process_title;
///
int function(const(char)* title) uv_set_process_title;
///
int function(size_t* rss) uv_resident_set_memory;
///
int function(double* uptime) uv_uptime;
///
uv_os_fd_t function(int fd) uv_get_osfhandle;

///
struct uv_timeval_t {
	///
	c_long tv_sec;
	///
	c_long tv_usec;
}

///
struct uv_rusage_t {
	/// user CPU time used
	uv_timeval_t ru_utime;
	/// system CPU time used
	uv_timeval_t ru_stime;
	/// maximum resident set size
	ulong ru_maxrss;
	/// integral shared memory size
	ulong ru_ixrss;
	/// integral unshared data size
	ulong ru_idrss;
	/// integral unshared stack size
	ulong ru_isrss;
	/// page reclaims (soft page faults)
	ulong ru_minflt;
	/// page faults (hard page faults)
	ulong ru_majflt;
	/// swaps
	ulong ru_nswap;
	/// block input operations
	ulong ru_inblock;
	/// block output operations
	ulong ru_oublock;
	/// IPC messages sent
	ulong ru_msgsnd;
	/// IPC messages received
	ulong ru_msgrcv;
	/// signals received
	ulong ru_nsignals;
	/// voluntary context switches
	ulong ru_nvcsw;
	/// involuntary context switches
	ulong ru_nivcsw;
}

///
int function(uv_rusage_t* rusage) uv_getrusage;

///
int function(char* buffer, size_t* size) uv_os_homedir;
///
int function(char* buffer, size_t* size) uv_os_tmpdir;
///
int function(uv_passwd_t* pwd) uv_os_get_passwd;
///
void function(uv_passwd_t* pwd) uv_os_free_passwd;

///
int function(uv_cpu_info_t** cpu_infos, int* count) uv_cpu_info;
///
void function(uv_cpu_info_t* cpu_infos, int count) uv_free_cpu_info;

///
int function(uv_interface_address_t** addresses, int* count) uv_interface_addresses;
///
void function(uv_interface_address_t* addresses, int count) uv_free_interface_addresses;

///
int function(const(char)* name, char* buffer, size_t* size) uv_os_getenv;
///
int function(const(char)* name, const(char)* value) uv_os_setenv;
///
int function(const(char)* name) uv_os_unsetenv;

///
int function(char* buffer, size_t* size) uv_os_gethostname;

///
enum uv_fs_type {
	///
	UV_FS_UNKNOWN = -1,
	///
	UV_FS_CUSTOM,
	///
	UV_FS_OPEN,
	///
	UV_FS_CLOSE,
	///
	UV_FS_READ,
	///
	UV_FS_WRITE,
	///
	UV_FS_SENDFILE,
	///
	UV_FS_STAT,
	///
	UV_FS_LSTAT,
	///
	UV_FS_FSTAT,
	///
	UV_FS_FTRUNCATE,
	///
	UV_FS_UTIME,
	///
	UV_FS_FUTIME,
	///
	UV_FS_ACCESS,
	///
	UV_FS_CHMOD,
	///
	UV_FS_FCHMOD,
	///
	UV_FS_FSYNC,
	///
	UV_FS_FDATASYNC,
	///
	UV_FS_UNLINK,
	///
	UV_FS_RMDIR,
	///
	UV_FS_MKDIR,
	///
	UV_FS_MKDTEMP,
	///
	UV_FS_RENAME,
	///
	UV_FS_SCANDIR,
	///
	UV_FS_LINK,
	///
	UV_FS_SYMLINK,
	///
	UV_FS_READLINK,
	///
	UV_FS_CHOWN,
	///
	UV_FS_FCHOWN,
	///
	UV_FS_REALPATH,
	///
	UV_FS_COPYFILE
}

/// uv_fs_t is a subclass of uv_req_t.
struct uv_fs_s {
	///
	mixin UV_REQ_FIELDS;
	///
	uv_fs_type fs_type;
	///
	uv_loop_t* loop;
	///
	uv_fs_cb cb;
	///
	ptrdiff_t result;
	///
	void* ptr;
	///
	const(char)* path;
	/// Stores the result of uv_fs_stat() and uv_fs_fstat().
	uv_stat_t statbuf;
	///
	mixin UV_FS_PRIVATE_FIELDS;
}

///
void function(uv_fs_t* req) uv_fs_req_cleanup;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, uv_fs_cb cb) uv_fs_close;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, int flags, int mode, uv_fs_cb cb) uv_fs_open;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, const(uv_buf_t)[] bufs, uint nbufs, long offset, uv_fs_cb cb) uv_fs_read;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_unlink;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, const(uv_buf_t)[] bufs, uint nbufs, long offset, uv_fs_cb cb) uv_fs_write;

/**
 * This flag can be used with uv_fs_copyfile() to return an error if the
 * destination already exists.
 */
enum UV_FS_COPYFILE_EXCL = 0x0001;

///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, const(char)* new_path, int flags, uv_fs_cb cb) uv_fs_copyfile;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, int mode, uv_fs_cb cb) uv_fs_mkdir;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* tpl, uv_fs_cb cb) uv_fs_mkdtemp;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_rmdir;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, int flags, uv_fs_cb cb) uv_fs_scandir;
///
int function(uv_fs_t* req, uv_dirent_t* ent) uv_fs_scandir_next;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_stat;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, uv_fs_cb cb) uv_fs_fstat;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, const(char)* new_path, uv_fs_cb cb) uv_fs_rename;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, uv_fs_cb cb) uv_fs_fsync;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, uv_fs_cb cb) uv_fs_fdatasync;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, long offset, uv_fs_cb cb) uv_fs_ftruncate;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file out_fd, uv_file in_fd, long in_offset, size_t length, uv_fs_cb cb) uv_fs_sendfile;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, int mode, uv_fs_cb cb) uv_fs_access;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, int mode, uv_fs_cb cb) uv_fs_chmod;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, double atime, double mtime, uv_fs_cb cb) uv_fs_utime;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, double atime, double mtime, uv_fs_cb cb) uv_fs_futime;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_lstat;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, const(char)* new_path, uv_fs_cb cb) uv_fs_link;

/**
 * This flag can be used with uv_fs_symlink() on Windows to specify whether
 * path argument points to a directory.
 */
enum UV_FS_SYMLINK_DIR = 0x0001;

/**
 * This flag can be used with uv_fs_symlink() on Windows to specify whether
 * the symlink is to be created using junction points.
 */
enum UV_FS_SYMLINK_JUNCTION = 0x0002;

///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, const(char)* new_path, int flags, uv_fs_cb cb) uv_fs_symlink;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_readlink;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_fs_cb cb) uv_fs_realpath;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, int mode, uv_fs_cb cb) uv_fs_fchmod;
///
int function(uv_loop_t* loop, uv_fs_t* req, const(char)* path, uv_uid_t uid, uv_gid_t gid, uv_fs_cb cb) uv_fs_chown;
///
int function(uv_loop_t* loop, uv_fs_t* req, uv_file file, uv_uid_t uid, uv_gid_t gid, uv_fs_cb cb) uv_fs_fchown;

///
enum uv_fs_event {
	///
	UV_RENAME = 1,
	///
	UV_CHANGE = 2
}

///
struct uv_fs_event_s {
	///
	mixin UV_HANDLE_FIELDS;
	/// private
	char* path;
	///
	mixin UV_FS_EVENT_PRIVATE_FIELDS;
}


/**
 * uv_fs_stat() based polling file watcher.
 */
struct uv_fs_poll_s {
	///
	mixin UV_HANDLE_FIELDS;
	/// Private, don't touch.
	void* poll_ctx;
}

///
int function(uv_loop_t* loop, uv_fs_poll_t* handle) uv_fs_poll_init;
///
int function(uv_fs_poll_t* handle, uv_fs_poll_cb poll_cb, const(char)* path, uint interval) uv_fs_poll_start;
///
int function(uv_fs_poll_t* handle) uv_fs_poll_stop;
///
int function(uv_fs_poll_t* handle, char* buffer, size_t* size) uv_fs_poll_getpath;

///
struct uv_signal_s {
	///
	mixin UV_HANDLE_FIELDS;
	///
	uv_signal_cb signal_cb;
	///
	int signum;
	///
	mixin UV_SIGNAL_PRIVATE_FIELDS;
}

///
int function(uv_loop_t* loop, uv_signal_t* handle) uv_signal_init;
///
int function(uv_signal_t* handle, uv_signal_cb signal_cb, int signum) uv_signal_start;
///
int function(uv_signal_t* handle, uv_signal_cb signal_cb, int signum) uv_signal_start_oneshot;
///
int function(uv_signal_t* handle) uv_signal_stop;

///
void function(double[3] avg) uv_loadavg;


/**
 * Flags to be passed to uv_fs_event_start().
 */
enum uv_fs_event_flags {
	/*
	 * By default, if the fs event watcher is given a directory name, we will
	 * watch for all events in that directory. This flags overrides this behavior
	 * and makes fs_event report only changes to the directory entry itself. This
	 * flag does not affect individual files watched.
	 * This flag is currently not implemented yet on any backend.
	 */
	UV_FS_EVENT_WATCH_ENTRY = 1,
	
	/**
	 * By default uv_fs_event will try to use a kernel interface such as inotify
	 * or kqueue to detect events. This may not work on remote filesystems such
	 * as NFS mounts. This flag makes fs_event fall back to calling stat() on a
	 * regular interval.
	 * This flag is currently not implemented yet on any backend.
	 */
	UV_FS_EVENT_STAT = 2,
	
	/**
	 * By default, event watcher, when watching directory, is not registering
	 * (is ignoring) changes in it's subdirectories.
	 * This flag will override this behaviour on platforms that support it.
	 */
	UV_FS_EVENT_RECURSIVE = 4
}

///
int function(uv_loop_t* loop, uv_fs_event_t* handle) uv_fs_event_init;
///
int function(uv_fs_event_t* handle, uv_fs_event_cb cb, const(char)* path, uint flags) uv_fs_event_start;
///
int function(uv_fs_event_t* handle) uv_fs_event_stop;
///
int function(uv_fs_event_t* handle, char* buffer, size_t* size) uv_fs_event_getpath;

///
int function(const(char)* ip, int port, sockaddr_in* addr) uv_ip4_addr;
///
int function(const(char)* ip, int port, sockaddr_in6* addr) uv_ip6_addr;

///
int function(const(sockaddr_in)* src, char* dst, size_t size) uv_ip4_name;
///
int function(const(sockaddr_in6)* src, char* dst, size_t size) uv_ip6_name;

///
int function(int af, const(void)* src, char* dst, size_t size) uv_inet_ntop;
///
int function(int af, const(char)* src, void* dst) uv_inet_pton;

///
int function(char* buffer, size_t* size) uv_exepath;

///
int function(char* buffer, size_t* size) uv_cwd;

///
int function(const(char)* dir) uv_chdir;

///
ulong function() uv_get_free_memory;
///
ulong function() uv_get_total_memory;

///
ulong function() uv_hrtime;

///
void function() uv_disable_stdio_inheritance;

///
int function(const(char)* filename, uv_lib_t* lib) uv_dlopen;
///
void function(uv_lib_t* lib) uv_dlclose;
///
int function(uv_lib_t* lib, const(char)* name, void** ptr) uv_dlsym;
///
const(char)* function(const(uv_lib_t)* lib) uv_dlerror;

///
int function(uv_mutex_t* handle) uv_mutex_init;
///
void function(uv_mutex_t* handle) uv_mutex_destroy;
///
void function(uv_mutex_t* handle) uv_mutex_lock;
///
int function(uv_mutex_t* handle) uv_mutex_trylock;
///
void function(uv_mutex_t* handle) uv_mutex_unlock;

///
int function(uv_rwlock_t* rwlock) uv_rwlock_init;
///
void function(uv_rwlock_t* rwlock) uv_rwlock_destroy;
///
void function(uv_rwlock_t* rwlock) uv_rwlock_rdlock;
///
int function(uv_rwlock_t* rwlock) uv_rwlock_tryrdlock;
///
void function(uv_rwlock_t* rwlock) uv_rwlock_rdunlock;
///
void function(uv_rwlock_t* rwlock) uv_rwlock_wrlock;
///
int function(uv_rwlock_t* rwlock) uv_rwlock_trywrlock;
///
void function(uv_rwlock_t* rwlock) uv_rwlock_wrunlock;

///
int function(uv_sem_t* sem, uint value) uv_sem_init;
///
void function(uv_sem_t* sem) uv_sem_destroy;
///
void function(uv_sem_t* sem) uv_sem_post;
///
void function(uv_sem_t* sem) uv_sem_wait;
///
int function(uv_sem_t* sem) uv_sem_trywait;

///
int function(uv_cond_t* cond) uv_cond_init;
///
void function(uv_cond_t* cond) uv_cond_destroy;
///
void function(uv_cond_t* cond) uv_cond_signal;
///
void function(uv_cond_t* cond) uv_cond_broadcast;

///
int function(uv_barrier_t* barrier, uint count) uv_barrier_init;
///
void function(uv_barrier_t* barrier) uv_barrier_destroy;
///
int function(uv_barrier_t* barrier) uv_barrier_wait;

///
void function(uv_cond_t* cond, uv_mutex_t* mutex) uv_cond_wait;
///
int function(uv_cond_t* cond, uv_mutex_t* mutex, ulong timeout) uv_cond_timedwait;

alias uv_once_callback = extern(C) void function();

///
void function(uv_once_t* guard, uv_once_callback callback) uv_once;

///
int function(uv_key_t* key) uv_key_create;
///
void function(uv_key_t* key) uv_key_delete;
///
void* function(uv_key_t* key) uv_key_get;
///
void function(uv_key_t* key, void* value) uv_key_set;

///
alias uv_thread_cb = extern(C) void function(void* arg);

///
int function(uv_thread_t* tid, uv_thread_cb entry, void* arg) uv_thread_create;
///
uv_thread_t function() uv_thread_self;
///
int function(uv_thread_t *tid) uv_thread_join;
///
int function(const(uv_thread_t)* t1, const(uv_thread_t)* t2) uv_thread_equal;

/// The presence of these unions force similar struct layout.
union uv_any_handle {
	///
	uv_async_t async;
	///
	uv_check_t check;
	///
	uv_fs_event_t fs_event;
	///
	uv_fs_poll_t fs_poll;
	///
	uv_handle_t handle;
	///
	uv_idle_t idle;
	///
	uv_pipe_t pipe;
	///
	uv_poll_t poll;
	///
	uv_prepare_t prepare;
	///
	uv_process_t process;
	///
	uv_stream_t stream;
	///
	uv_tcp_t tcp;
	///
	uv_timer_t timer;
	///
	uv_tty_t tty;
	///
	uv_udp_t udp;
	///
	uv_signal_t signal;
}

/// Ditto
union uv_any_req {
	///
	uv_req_t req;
	///
	uv_connect_t connect;
	///
	uv_write_t write;
	///
	uv_shutdown_t shutdown;
	///
	uv_udp_send_t udp_send;
	///
	uv_fs_t fs;
	///
	uv_work_t work;
	///
	uv_getaddrinfo_t getaddrinfo;
	///
	uv_getnameinfo_t getnameinfo;
}

///
struct uv_loop_s {
	/// User data - use this for whatever.
	void* data;
	/// Loop reference counting.
	uint active_handles;
	///
	void*[2] handle_queue;
	///
	void*[2] active_reqs;
	/// Internal flag to signal loop stop.
	uint stop_flag;
	///
	mixin UV_LOOP_PRIVATE_FIELDS;
}
