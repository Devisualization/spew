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
module cf.spew.bindings.libuv.uv_win;
import cf.spew.bindings.libuv.uv;
version(Windows):

__gshared nothrow @nogc @system extern(C):

import core.sys.windows.winsock2;
public import core.sys.windows.winsock2;
public import core.sys.windows.winbase : OVERLAPPED, HANDLE, WCHAR, WORD, BYTE, DWORD;
public import core.sys.windows.mswsock : LPFN_ACCEPTEX, LPFN_CONNECTEX;
public import core.sys.windows.wincon : INPUT_RECORD, COORD;
///
alias sockaddr_storage = SOCKADDR_STORAGE;

///
struct addrinfoW {
	///
	int ai_flags;
	///
	int ai_family;
	///
	int ai_socktype;
	///
	int ai_protocol;
	///
	size_t ai_addrlen;
	///
	PWSTR ai_canonname;
	///
	sockaddr* ai_addr;
	///
	addrinfoW* ai_next;
}
///
alias ADDRINFOW = addrinfoW;
///
alias PADDRINFOW = ADDRINFOW*;

///
struct WSAPOLLFD {
	///
	SOCKET fd;
	///
	short events;
	///
	short revents;
}
///
alias PWSAPOLLFD = WSAPOLLFD*;
///
alias LPWSAPOLLFD = WSAPOLLFD*;

///
enum LOCALE_INVARIANT = 0x007f;

import core.sys.windows.mswsock;
// #include <ws2tcpip.h>
import core.sys.windows.windows;

// #include <process.h>
import core.stdc.signal;
// #include <fcntl.h>
import core.sys.windows.stat;

public import cf.spew.bindings.libuv.tree;
public import cf.spew.bindings.libuv.uv_threadpool;

///
enum MAX_PIPENAME_LEN = 256;
///
enum S_IFLNK = 0xA000;

/**
 * Additional signals supported by uv_signal and or uv_kill. The CRT defines
 * the following signals already:
 *
 *   #define SIGINT           2
 *   #define SIGILL           4
 *   #define SIGABRT_COMPAT   6
 *   #define SIGFPE           8
 *   #define SIGSEGV         11
 *   #define SIGTERM         15
 *   #define SIGBREAK        21
 *   #define SIGABRT         22
 *
 * The additional signals have values that are common on other Unix
 * variants (Linux and Darwin)
 */
enum SIGHUP = 1;
/// DItto
enum SIGKILL = 9;
/// DItto
enum SIGWINCH = 28;

///
enum SIGABRT_COMPAT = 6;

///
extern(Windows) {
	///
	alias BOOL function(PVOID lpOutputBuffer, DWORD dwReceiveDataLength, DWORD dwLocalAddressLength, DWORD dwRemoteAddressLength, LPSOCKADDR* LocalSockaddr, LPINT LocalSockaddrLength, LPSOCKADDR* RemoteSockaddr, LPINT RemoteSockaddrLength) LPFN_GETACCEPTEXSOCKADDRS;
	///
	alias BOOL function(SOCKET hSocket, LPOVERLAPPED lpOverlapped, DWORD dwFlags, DWORD reserved) LPFN_DISCONNECTEX;
	///
	alias BOOL function(SOCKET hSocket, HANDLE hFile, DWORD nNumberOfBytesToWrite, DWORD nNumberOfBytesPerSend, LPOVERLAPPED lpOverlapped, LPTRANSMIT_FILE_BUFFERS lpTransmitBuffers,DWORD dwFlags) LPFN_TRANSMITFILE;
}
///
const GUID WSAID_GETACCEPTEXSOCKADDRS = {0xb5367df2, 0xcbac, 0x11cf,[0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92]};
///
const GUID WSAID_DISCONNECTEX = {0x7fda2e11, 0x8630, 0x436f,[0xa0, 0x31, 0xf5, 0x36, 0xa6, 0xee, 0xc1, 0x57]};
///
const GUID WSAID_TRANSMITFILE = {0xb5367df0, 0xcbac, 0x11cf,[0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92]};

///
alias RTL_SRWLOCK = PVOID;
///
alias SRWLOCK = RTL_SRWLOCK;
///
alias PSRWLOCK = RTL_SRWLOCK*;

///
alias LPFN_WSARECV = int function(SOCKET socket, LPWSABUF buffers, DWORD buffer_count, LPDWORD bytes, LPDWORD flags, LPWSAOVERLAPPED overlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE completion_routine);
///
alias LPFN_WSARECVFROM = int function(SOCKET socket, LPWSABUF buffers, DWORD buffer_count, LPDWORD bytes, LPDWORD flags, sockaddr* addr, LPINT addr_len, LPWSAOVERLAPPED overlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE completion_routine);

///
alias NTSTATUS = LONG;
///
alias PNTSTATUS = NTSTATUS*;

///
alias CONDITION_VARIABLE = PVOID;
///
alias PCONDITION_VARIABLE = CONDITION_VARIABLE*;

///
struct _AFD_POLL_HANDLE_INFO {
	///
	HANDLE Handle;
	///
	ULONG Events;
	///
	NTSTATUS Status;
}
///
alias AFD_POLL_HANDLE_INFO = _AFD_POLL_HANDLE_INFO;
///
alias PAFD_POLL_HANDLE_INFO = AFD_POLL_HANDLE_INFO*;

///
struct _AFD_POLL_INFO {
	///
	LARGE_INTEGER Timeout;
	///
	ULONG NumberOfHandles;
	///
	ULONG Exclusive;
	///
	AFD_POLL_HANDLE_INFO[1] Handles;
}
///
alias AFD_POLL_INFO = _AFD_POLL_INFO;
///
alias PAFD_POLL_INFO = AFD_POLL_INFO*;

///
enum UV_MSAFD_PROVIDER_COUNT = 3;

/**
 * It should be possible to cast uv_buf_t[] to WSABUF[]
 * see http://msdn.microsoft.com/en-us/library/ms741542(v=vs.85).aspx
 */
struct uv_buf_t {
	///
	ULONG len;
	///
	char* base;
}

///
alias
	///
	uv_file = int,
	///
	uv_os_sock_t = SOCKET,
	///
	uv_os_fd_t = HANDLE,
	///
	uv_thread_t = HANDLE,
	///
	uv_sem_t = HANDLE,
	///
	uv_mutex_t = CRITICAL_SECTION;

/**
 * This condition variable implementation is based on the SetEvent solution
 * (section 3.2) at http://www.cs.wustl.edu/~schmidt/win32-cv-1.html
 * We could not use the SignalObjectAndWait solution (section 3.4) because
 * it want the 2nd argument (type uv_mutex_t) of uv_cond_wait() and
 * uv_cond_timedwait() to be HANDLEs, but we use CRITICAL_SECTIONs.
 */
union uv_cond_t {
	///
	CONDITION_VARIABLE cond_var;
	///
	struct Fallback {
		///
		uint waiters_count;
		///
		CRITICAL_SECTION waiters_count_lock;
		///
		HANDLE signal_event;
		///
		HANDLE broadcast_event;
	}
	///
	Fallback fallback;
}

///
union uv_rwlock_t {
	///
	struct State_ {
		///
		uint num_readers_;
		///
		CRITICAL_SECTION num_readers_lock_;
		///
		HANDLE write_semaphore_;
	}
	///
	State_ state_;
	/// TODO: remove me in v2.x.
	struct Unused1_ {
		///
		SRWLOCK unused_;
	}
	///
	Unused1_ unused1_;
	/// TODO: remove me in v2.x.
	struct Unused2_ {
		///
		uv_mutex_t unused1_;
		///
		uv_mutex_t unused2_;
	}
	///
	Unused2_ unused2_;
}

///
struct uv_barrier_t {
	///
	uint n;
	///
	uint count;
	///
	uv_mutex_t mutex;
	///
	uv_sem_t turnstile1;
	///
	uv_sem_t turnstile2;
}

///
struct uv_key_t {
	///
	DWORD tls_index;
}

///
enum UV_ONCE_INIT = uv_once_t(0, null);

///
struct uv_once_s {
	///
	ubyte ran;
	///
	HANDLE event;
}
///
alias uv_once_t = uv_once_s;

/// Platform-specific definitions for uv_spawn support.
alias uv_uid_t = ubyte;
///
alias uv_gid_t = ubyte;

///
struct uv__dirent_s {
	///
	int d_type;
	///
	char[1] d_name;
}
///
alias uv__dirent_t = uv__dirent_s;

///
enum {
	///
	HAVE_DIRENT_TYPES = true,
	///
	UV__DT_DIR = uv_dirent_type_t.UV_DIRENT_DIR,
	///
	UV__DT_FILE = uv_dirent_type_t.UV_DIRENT_FILE,
	///
	UV__DT_LINK = uv_dirent_type_t.UV_DIRENT_LINK,
	///
	UV__DT_FIFO = uv_dirent_type_t.UV_DIRENT_FIFO,
	///
	UV__DT_SOCKET = uv_dirent_type_t.UV_DIRENT_SOCKET,
	///
	UV__DT_CHAR = uv_dirent_type_t.UV_DIRENT_CHAR,
	///
	UV__DT_BLOCK = uv_dirent_type_t.UV_DIRENT_BLOCK
}

/// Platform-specific definitions for uv_dlopen support.

// #define UV_DYNAMIC FAR WINAPI

///
struct uv_lib_t {
	///
	HMODULE handle;
	///
	char* errmsg;
}

///
mixin RB_HEAD!("uv_timer_tree_s", uv_timer_s);

///
mixin template UV_LOOP_PRIVATE_FIELDS() {
	/// The loop's I/O completion port
	HANDLE iocp;
	/// The current time according to the event loop. in msecs.
	ulong time;
	/// Tail of a single-linked circular queue of pending reqs. If the queue
	/// is empty, tail_ is NULL. If there is only one item,
	/// tail_->next_req == tail_
	uv_req_t* pending_reqs_tail;
	/// Head of a single-linked list of closed handles
	uv_handle_t* endgame_handles;
	/// The head of the timers tree
	uv_timer_tree_s timers;
	/// Lists of active loop (prepare / check / idle) watchers
	uv_prepare_t* prepare_handles;
	///
	uv_check_t* check_handles;
	///
	uv_idle_t* idle_handles;
	/// This pointer will refer to the prepare/check/idle handle whose
	/// callback is scheduled to be called next. This is needed to allow
	/// safe removal from one of the lists above while that list being
	/// iterated over.
	uv_prepare_t* next_prepare_handle;
	///
	uv_check_t* next_check_handle;
	///
	uv_idle_t* next_idle_handle;
	//// This handle holds the peer sockets for the fast variant of uv_poll_t
	SOCKET[UV_MSAFD_PROVIDER_COUNT] poll_peer_sockets;
	/// Counter to keep track of active tcp streams
	uint active_tcp_streams;
	/// Counter to keep track of active udp streams
	uint active_udp_streams;
	/// Counter to started timer
	ulong timer_counter;
	/// Threadpool
	void*[2] wq;
	///
	uv_mutex_t wq_mutex;
	///
	uv_async_t wq_async;
}

///
enum UV_REQ_TYPE_PRIVATE = q{
	// TODO: remove the req suffix

	///
	UV_ACCEPT,
	///
	UV_FS_EVENT_REQ,
	///
	UV_POLL_REQ,
	///
	UV_PROCESS_EXIT,
	///
	UV_READ,
	///
	UV_UDP_RECV,
	///
	UV_WAKEUP,
	///
	UV_SIGNAL_REQ,
};

///
mixin template UV_REQ_PRIVATE_FIELDS() {
	///
	union U {
		/// Used by I/O operations
		struct IO {
			///
			OVERLAPPED overlapped;
			///
			size_t queued_bytes;
		}
		///
		IO io;
	}
	///
	U u;
	///
	uv_req_s* next_req;
}

///
mixin template UV_WRITE_PRIVATE_FIELDS() {
	///
	int ipc_header;
	///
	uv_buf_t write_buffer;
	///
	HANDLE event_handle;
	///
	HANDLE wait_handle;
}

///
mixin template UV_CONNECT_PRIVATE_FIELDS () {}
///
mixin template UV_SHUTDOWN_PRIVATE_FIELDS() {}
///
mixin template UV_UDP_SEND_PRIVATE_FIELDS() {}

///
mixin template UV_PRIVATE_REQ_TYPES() {
	///
	struct uv_pipe_accept_s {
		///
		mixin UV_REQ_FIELDS;
		///
		HANDLE pipeHandle;
		///
		uv_pipe_accept_s* next_pending;
	}
	///
	alias uv_pipe_accept_t = uv_pipe_accept_s;

	///
	struct uv_tcp_accept_s {
		///
		mixin UV_REQ_FIELDS;
		///
		SOCKET accept_socket;
		///
		char[sockaddr_storage.sizeof * 2 + 32] accept_buffer;
		///
		HANDLE event_handle;
		///
		HANDLE wait_handle;
		///
		uv_tcp_accept_s* next_pending;
	}
	///
	alias uv_tcp_accept_t = uv_tcp_accept_s;

	///
	struct uv_read_s {
		///
		mixin UV_REQ_FIELDS;
		///
		HANDLE event_handle;
		///
		HANDLE wait_handle;
	}
	///
	alias uv_read_t = uv_read_s;
}

///
mixin template uv_stream_connection_fields() {
	///
	uint write_reqs_pending;
	///
	uv_shutdown_t* shutdown_req;
}

///
mixin template uv_stream_server_fields() {
	///
	uv_connection_cb connection_cb;
}

///
mixin template UV_STREAM_PRIVATE_FIELDS() {
	///
	uint reqs_pending;
	///
	int activecnt;
	///
	uv_read_t read_req;
	///
	union Stream {
		///
		struct Conn {
			///
			mixin uv_stream_connection_fields;
		}
		///
		Conn conn;
		///
		struct Serv { 
			///
			mixin uv_stream_server_fields;
		}
		///
		Serv serv;
	}
	///
	Stream stream;
}

///
mixin template uv_tcp_server_fields() {
	///
	uv_tcp_accept_t* accept_reqs;
	///
	uint processed_accepts;
	///
	uv_tcp_accept_t* pending_accepts;
	///
	LPFN_ACCEPTEX func_acceptex;
}

///
mixin template uv_tcp_connection_fields() {
	///
	uv_buf_t read_buffer;
	///
	LPFN_CONNECTEX func_connectex;
}

///
mixin template UV_TCP_PRIVATE_FIELDS() {
	///
	SOCKET socket;
	///
	int delayed_error;
	///
	union TCP {
		///
		struct Serv {
			///
			mixin uv_tcp_server_fields;
		}
		///
		Serv serv;
		///
		struct Conn {
			///
			mixin uv_tcp_connection_fields;
		}
		///
		Conn conn;
	}
	///
	TCP tcp;
}

///
mixin template UV_UDP_PRIVATE_FIELDS() {
	///
	SOCKET socket;
	///
	uint reqs_pending;
	///
	int activecnt;
	///
	uv_req_t recv_req;
	///
	uv_buf_t recv_buffer;
	///
	sockaddr_storage recv_from;
	///
	int recv_from_len;
	///
	uv_udp_recv_cb recv_cb;
	///
	uv_alloc_cb alloc_cb;
	///
	LPFN_WSARECV func_wsarecv;
	///
	LPFN_WSARECVFROM func_wsarecvfrom;
}

///
mixin template uv_pipe_server_fields() {
	///
	int pending_instances;
	///
	uv_pipe_accept_t* accept_reqs;
	///
	uv_pipe_accept_t* pending_accepts;
}

///
mixin template uv_pipe_connection_fields() {
	///
	uv_timer_t* eof_timer;
	///
	uv_write_t ipc_header_write_req;
	///
	int ipc_pid;
	///
	ulong remaining_ipc_rawdata_bytes;
	///
	struct Pending_ipc_info {
		///
		void*[2] queue;
		///
		int queue_len;
	}
	///
	Pending_ipc_info pending_ipc_info;
	///
	uv_write_t* non_overlapped_writes_tail;
	///
	uv_mutex_t readfile_mutex;
	///
	HANDLE readfile_thread;
}

///
mixin template UV_PIPE_PRIVATE_FIELDS() {
	///
	HANDLE handle;
	///
	WCHAR* name;
	///
	union Pipe {
		///
		struct Serv {
			///
			mixin uv_pipe_server_fields;
		}
		///
		Serv serv;
		///
		struct Conn {
			///
			mixin uv_pipe_connection_fields;
		}
		///
		Conn conn;
	}
	///
	Pipe pipe;
}

/// TODO: put the parser states in an union - TTY handles are always
/// half-duplex so read-state can safely overlap write-state.
mixin template UV_TTY_PRIVATE_FIELDS() {
	///
	HANDLE handle;
	///
	union TTY {
		///
		struct RD {
			/// Used for readable TTY handles
			/// TODO: remove me in v2.x.
			HANDLE unused_;
			///
			uv_buf_t read_line_buffer;
			///
			HANDLE read_raw_wait;
			/// Fields used for translating win keystrokes into vt100 characters
			char[8] last_key;
			///
			ubyte last_key_offset;
			///
			ubyte last_key_len;
			///
			WCHAR last_utf16_high_surrogate;
			///
			INPUT_RECORD last_input_record;
		}
		///
		RD rd;
		///
		struct WR {
			/// Used for writable TTY handles
			/// utf8-to-utf16 conversion state
			uint utf8_codepoint;
			///
			ubyte utf8_bytes_left;
			/// eol conversion state
			ubyte previous_eol;
			/// ansi parser state
			ubyte ansi_parser_state;
			///
			ubyte ansi_csi_argc;
			///
			ushort[4] ansi_csi_argv;
			///
			COORD saved_position;
			///
			WORD saved_attributes;
		}
		///
		WR wr;
	}
	///
	TTY tty;
}

///
mixin template UV_POLL_PRIVATE_FIELDS() {
	///
	SOCKET socket;
	/// Used in fast mode
	SOCKET peer_socket;
	///
	AFD_POLL_INFO afd_poll_info_1;
	///
	AFD_POLL_INFO afd_poll_info_2;
	/// Used in fast and slow mode.
	uv_req_t poll_req_1;
	///
	uv_req_t poll_req_2;
	///
	ubyte submitted_events_1;
	///
	ubyte submitted_events_2;
	///
	ubyte mask_events_1;
	///
	ubyte mask_events_2;
	///
	ubyte events;
}

///
mixin template UV_TIMER_PRIVATE_FIELDS() {
	///
	RB_ENTRY!(uv_timer_s) tree_entry;
	///
	ulong due;
	///
	ulong repeat;
	///
	ulong start_id;
	///
	uv_timer_cb timer_cb;
}

///
mixin template UV_ASYNC_PRIVATE_FIELDS() {
	///
	uv_req_s async_req;
	///
	uv_async_cb async_cb;
	/// char to avoid alignment issues
	char async_sent;
}

///
mixin template UV_PREPARE_PRIVATE_FIELDS() {
	///
	uv_prepare_t* prepare_prev;
	///
	uv_prepare_t* prepare_next;
	///
	uv_prepare_cb prepare_cb;
}

///
mixin template UV_CHECK_PRIVATE_FIELDS() {
	///
	uv_check_t* check_prev;
	///
	uv_check_t* check_next;
	///
	uv_check_cb check_cb;
}

///
mixin template UV_IDLE_PRIVATE_FIELDS() {
	///
	uv_idle_t* idle_prev;
	///
	uv_idle_t* idle_next;
	///
	uv_idle_cb idle_cb;
}

///
mixin template UV_HANDLE_PRIVATE_FIELDS() {
	///
	uv_handle_t* endgame_next;
	///
	uint flags;
}

///
mixin template UV_GETADDRINFO_PRIVATE_FIELDS() {
	///
	uv__work work_req;
	///
	uv_getaddrinfo_cb getaddrinfo_cb;
	///
	void* alloc;
	///
	WCHAR* node;
	///
	WCHAR* service;
	/// The addrinfoW field is used to store a pointer to the hints, and
	/// later on to store the result of GetAddrInfoW. The final result will
	/// be converted to struct addrinfo* and stored in the addrinfo field.
	addrinfoW* addrinfow;
	///
	addrinfo* addrinfo_;
	///
	int retcode;
}

///
mixin template UV_GETNAMEINFO_PRIVATE_FIELDS() {
	///
	uv__work work_req;
	///
	uv_getnameinfo_cb getnameinfo_cb;
	///
	sockaddr_storage storage;
	///
	int flags;
	///
	char[NI_MAXHOST] host;
	///
	char[NI_MAXSERV] service;
	///
	int retcode;
}

///
mixin template UV_PROCESS_PRIVATE_FIELDS() {
	///
	struct uv_process_exit_s {
		///
		mixin UV_REQ_FIELDS;
	}
	///
	uv_process_exit_s exit_req;
	///
	BYTE* child_stdio_buffer;
	///
	int exit_signal;
	///
	HANDLE wait_handle;
	///
	HANDLE process_handle;
	///
	char exit_cb_pending;
}

///
mixin template UV_FS_PRIVATE_FIELDS() {
	///
	uv__work work_req;
	///
	int flags;
	///
	DWORD sys_errno_;
	///
	union File {
		/// TODO: remove me in 0.9.
		WCHAR* pathw;
		///
		int fd;
	}
	///
	File file;
	///
	union FS {
		///
		struct Info {
			///
			int mode;
			///
			WCHAR* new_pathw;
			///
			int file_flags;
			///
			int fd_out;
			///
			uint nbufs;
			///
			uv_buf_t* bufs;
			///
			long offset;
			///
			uv_buf_t[4] bufsml;
		}
		///
		Info info;
		///
		struct Time {
			///
			double atime;
			///
			double mtime;
		}
		///
		Time time;
	}
	///
	FS fs;
}

///
mixin template UV_WORK_PRIVATE_FIELDS() {
	///
	uv__work work_req;
}

///
mixin template UV_FS_EVENT_PRIVATE_FIELDS() {
	///
	struct uv_fs_event_req_s {
		///
		mixin UV_REQ_FIELDS;
	}
	///
	uv_fs_event_req_s req;
	///
	HANDLE dir_handle;
	///
	int req_pending;
	///
	uv_fs_event_cb cb;
	///
	WCHAR* filew;
	///
	WCHAR* short_filew;
	///
	WCHAR* dirw;
	///
	char* buffer;
}

///
mixin template UV_SIGNAL_PRIVATE_FIELDS() {
	///
	RB_ENTRY!(uv_signal_s) tree_entry;
	///
	uv_req_s signal_req;
	///
	ulong pending_signum;
}

///
enum {
	///
	F_OK = 0,
	///
	R_OK = 4,
	///
	W_OK = 2,
	///
	X_OK = 1
}
