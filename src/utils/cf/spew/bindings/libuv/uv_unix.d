module cf.spew.bindings.libuv.uv_unix;
__EOF__
version(Posix):
__gshared nothrow @nogc @system extern(C):

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
	NI_MAXHOST = 1025,
	NI_MAXSERV = 32
}

static if (!__traits(compiles, {mixin UV_IO_PRIVATE_PLATFORM_FIELDS;})) {
	mixin template UV_IO_PRIVATE_PLATFORM_FIELDS() {}
}

alias uv__io_cb = void function(uv_loop_s* loop, uv__io_s* w, uint events);
alias uv__io_t = uv__io_s;

struct uv__io_s {
	uv__io_cb cb;
	void*[2] pending_queue;
	void*[2] watcher_queue;
	/// Pending event mask i.e. mask at next tick.
	uint pevents;
	/// Current event mask.
	uint events;
	int fd;
	mixin UV_IO_PRIVATE_PLATFORM_FIELDS;
}

alias uv__async_cb = void function(uv_loop_s* loop, uv__async* w, uint nevents);

struct uv__async {
	uv__async_cb cb;
	uv__io_t io_watcher;
	int wfd;
}

static if (!__traits(compiles, {alias T = UV_PLATFORM_SEM_T;})) {
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
	char* base;
	size_t len;
}

alias uv_file = int;
alias uv_os_sock_t = int;
alias uv_os_fd_t = int;

alias UV_ONCE_INIT = PTHREAD_ONCE_INIT;

alias
	uv_once_t = pthread_once_t,
	uv_thread_t = pthread_t,
	uv_mutex_t = pthread_mutex_t,
	uv_rwlock_t = pthread_rwlock_t,
	uv_sem_t = UV_PLATFORM_SEM_T,
	uv_cond_t = pthread_cond_t,
	uv_key_t = pthread_key_t,
	uv_barrier_t = pthread_barrier_t;


/// Platform-specific definitions for uv_spawn support.
alias
	uv_gid_t =gid_t,
	uv_uid_t = uid_t;

alias uv__dirent_t = dirent;

#if defined(DT_UNKNOWN)
# define HAVE_DIRENT_TYPES
# if defined(DT_REG)
#  define UV__DT_FILE DT_REG
# else
#  define UV__DT_FILE -1
# endif
# if defined(DT_DIR)
#  define UV__DT_DIR DT_DIR
# else
#  define UV__DT_DIR -2
# endif
# if defined(DT_LNK)
#  define UV__DT_LINK DT_LNK
# else
#  define UV__DT_LINK -3
# endif
# if defined(DT_FIFO)
#  define UV__DT_FIFO DT_FIFO
# else
#  define UV__DT_FIFO -4
# endif
# if defined(DT_SOCK)
#  define UV__DT_SOCKET DT_SOCK
# else
#  define UV__DT_SOCKET -5
# endif
# if defined(DT_CHR)
#  define UV__DT_CHAR DT_CHR
# else
#  define UV__DT_CHAR -6
# endif
# if defined(DT_BLK)
#  define UV__DT_BLOCK DT_BLK
# else
#  define UV__DT_BLOCK -7
# endif
#endif

/* Platform-specific definitions for uv_dlopen support. */
#define UV_DYNAMIC /* empty */

typedef struct {
	void* handle;
	char* errmsg;
} uv_lib_t;

#define UV_LOOP_PRIVATE_FIELDS                                                \
unsigned long flags;                                                        \
int backend_fd;                                                             \
void* pending_queue[2];                                                     \
void* watcher_queue[2];                                                     \
uv__io_t** watchers;                                                        \
unsigned int nwatchers;                                                     \
unsigned int nfds;                                                          \
void* wq[2];                                                                \
uv_mutex_t wq_mutex;                                                        \
uv_async_t wq_async;                                                        \
uv_rwlock_t cloexec_lock;                                                   \
uv_handle_t* closing_handles;                                               \
void* process_handles[2];                                                   \
void* prepare_handles[2];                                                   \
void* check_handles[2];                                                     \
void* idle_handles[2];                                                      \
void* async_handles[2];                                                     \
struct uv__async async_watcher;                                             \
struct {                                                                    \
void* min;                                                                \
unsigned int nelts;                                                       \
} timer_heap;                                                               \
uint64_t timer_counter;                                                     \
uint64_t time;                                                              \
int signal_pipefd[2];                                                       \
uv__io_t signal_io_watcher;                                                 \
uv_signal_t child_watcher;                                                  \
int emfile_fd;                                                              \
UV_PLATFORM_LOOP_FIELDS                                                     \

#define UV_REQ_TYPE_PRIVATE /* empty */

#define UV_REQ_PRIVATE_FIELDS  /* empty */

#define UV_PRIVATE_REQ_TYPES /* empty */

#define UV_WRITE_PRIVATE_FIELDS                                               \
void* queue[2];                                                             \
unsigned int write_index;                                                   \
uv_buf_t* bufs;                                                             \
unsigned int nbufs;                                                         \
int error;                                                                  \
uv_buf_t bufsml[4];                                                         \

#define UV_CONNECT_PRIVATE_FIELDS                                             \
void* queue[2];                                                             \

#define UV_SHUTDOWN_PRIVATE_FIELDS /* empty */

#define UV_UDP_SEND_PRIVATE_FIELDS                                            \
void* queue[2];                                                             \
struct sockaddr_storage addr;                                               \
unsigned int nbufs;                                                         \
uv_buf_t* bufs;                                                             \
ssize_t status;                                                             \
uv_udp_send_cb send_cb;                                                     \
uv_buf_t bufsml[4];                                                         \

#define UV_HANDLE_PRIVATE_FIELDS                                              \
uv_handle_t* next_closing;                                                  \
unsigned int flags;                                                         \

#define UV_STREAM_PRIVATE_FIELDS                                              \
uv_connect_t *connect_req;                                                  \
uv_shutdown_t *shutdown_req;                                                \
uv__io_t io_watcher;                                                        \
void* write_queue[2];                                                       \
void* write_completed_queue[2];                                             \
uv_connection_cb connection_cb;                                             \
int delayed_error;                                                          \
int accepted_fd;                                                            \
void* queued_fds;                                                           \
UV_STREAM_PRIVATE_PLATFORM_FIELDS                                           \

#define UV_TCP_PRIVATE_FIELDS /* empty */

#define UV_UDP_PRIVATE_FIELDS                                                 \
uv_alloc_cb alloc_cb;                                                       \
uv_udp_recv_cb recv_cb;                                                     \
uv__io_t io_watcher;                                                        \
void* write_queue[2];                                                       \
void* write_completed_queue[2];                                             \

#define UV_PIPE_PRIVATE_FIELDS                                                \
const char* pipe_fname; /* strdup'ed */

#define UV_POLL_PRIVATE_FIELDS                                                \
uv__io_t io_watcher;

#define UV_PREPARE_PRIVATE_FIELDS                                             \
uv_prepare_cb prepare_cb;                                                   \
void* queue[2];                                                             \

#define UV_CHECK_PRIVATE_FIELDS                                               \
uv_check_cb check_cb;                                                       \
void* queue[2];                                                             \

#define UV_IDLE_PRIVATE_FIELDS                                                \
uv_idle_cb idle_cb;                                                         \
void* queue[2];                                                             \

#define UV_ASYNC_PRIVATE_FIELDS                                               \
uv_async_cb async_cb;                                                       \
void* queue[2];                                                             \
int pending;                                                                \

#define UV_TIMER_PRIVATE_FIELDS                                               \
uv_timer_cb timer_cb;                                                       \
void* heap_node[3];                                                         \
uint64_t timeout;                                                           \
uint64_t repeat;                                                            \
uint64_t start_id;

#define UV_GETADDRINFO_PRIVATE_FIELDS                                         \
struct uv__work work_req;                                                   \
uv_getaddrinfo_cb cb;                                                       \
struct addrinfo* hints;                                                     \
char* hostname;                                                             \
char* service;                                                              \
struct addrinfo* addrinfo;                                                  \
int retcode;

#define UV_GETNAMEINFO_PRIVATE_FIELDS                                         \
struct uv__work work_req;                                                   \
uv_getnameinfo_cb getnameinfo_cb;                                           \
struct sockaddr_storage storage;                                            \
int flags;                                                                  \
char host[NI_MAXHOST];                                                      \
char service[NI_MAXSERV];                                                   \
int retcode;

#define UV_PROCESS_PRIVATE_FIELDS                                             \
void* queue[2];                                                             \
int status;                                                                 \

#define UV_FS_PRIVATE_FIELDS                                                  \
const char *new_path;                                                       \
uv_file file;                                                               \
int flags;                                                                  \
mode_t mode;                                                                \
unsigned int nbufs;                                                         \
uv_buf_t* bufs;                                                             \
off_t off;                                                                  \
uv_uid_t uid;                                                               \
uv_gid_t gid;                                                               \
double atime;                                                               \
double mtime;                                                               \
struct uv__work work_req;                                                   \
uv_buf_t bufsml[4];                                                         \

#define UV_WORK_PRIVATE_FIELDS                                                \
struct uv__work work_req;

#define UV_TTY_PRIVATE_FIELDS                                                 \
struct termios orig_termios;                                                \
int mode;

#define UV_SIGNAL_PRIVATE_FIELDS                                              \
/* RB_ENTRY(uv_signal_s) tree_entry; */                                     \
struct {                                                                    \
struct uv_signal_s* rbe_left;                                             \
struct uv_signal_s* rbe_right;                                            \
struct uv_signal_s* rbe_parent;                                           \
int rbe_color;                                                            \
} tree_entry;                                                               \
/* Use two counters here so we don have to fiddle with atomics. */          \
unsigned int caught_signals;                                                \
unsigned int dispatched_signals;

#define UV_FS_EVENT_PRIVATE_FIELDS                                            \
uv_fs_event_cb cb;                                                          \
UV_PLATFORM_FS_EVENT_FIELDS