module cf.spew.bindings.libuv.loader;
import cf.spew.bindings.symbolloader;

/// uses GC because it is "smart" in loading the library
struct LibUVLoader {
	private {
		SharedLib loader;
		string tempFile;

		version(OSX) {
			static string[] ToLoadFiles = ["libuv.dylib", "libuv.so"];
			static string NugetFile = "runtimes/osx/native/libuv.dylib";
		} else version(linux) {
			static string[] ToLoadFiles = ["libuv.so"];
			version(ARM) {
				static if (size_t.sizeof == 8) {
					static string NugetFile = "runtimes/linux-arm64/native/libuv.so";
				} else static if (size_t.sizeof == 4) {
					static string NugetFile = "runtimes/linux-arm/native/libuv.so";
				}
			}
		} else version(Windows) {
			static string[] ToLoadFiles = ["libuv.dll"];
			version(ARM) {
				static string NugetFile = "runtimes/win-arm/native/libuv.dll";
			} else static if (size_t.sizeof == 8) {
				static string NugetFile = "runtimes/win-x64/native/libuv.dll";
			} else static if (size_t.sizeof == 4) {
				static string NugetFile = "runtimes/win-x86/native/libuv.dll";
			}
		} else static assert(0, "Unsupported platform");
	}
	@disable this(this);

	/// File can be null
	this(string file) {
		try {
			loader.load(file ~ ToLoadFiles);
		} catch (Exception e) {
			static if (__traits(compiles, {string s = NugetFile; })) {
				import std.zip;
				import std.file : read, write, dirEntries, SpanMode, tempDir, mkdirRecurse, exists;
				import std.path : buildPath;
				import std.process : thisProcessID, executeShell;
				import std.conv : text;
				import std.zlib : uncompress;

				string nugetFile;
				foreach(string file2; dirEntries(".", "libuv.*.nupkg", SpanMode.shallow)) {
					nugetFile = file2;
				}

				tempFile = buildPath(tempDir(), thisProcessID.text);
				if (!exists(tempFile)) mkdirRecurse(tempFile);

				// try using 7-zip first!
				// std.zlib uncompress is a bit broken :(
				executeShell("7z e \"" ~ nugetFile ~ "\" \"" ~ NugetFile ~ "\" -o " ~ tempFile ~ "\"");
				// and this syntax right not? It is available with Cygwin at the very least
				executeShell("unzip -j \"" ~ nugetFile ~ "\" \"" ~ NugetFile ~ "\" -d \"" ~ tempFile ~ "\"");

				tempFile = buildPath(tempFile, "libuv.dll");
				if (exists(tempFile)) {
				} else {
					ZipArchive archive = new ZipArchive(read(nugetFile));
					foreach(am; archive.directory()) {
						if (am.name == NugetFile) {
							ubyte[] data = am.compressedData().dup;
							write(tempFile, am.expandedData);
							break;
						}
					}
				}

				if (tempFile is null || !exists(tempFile)) throw e;

				loader.load([tempFile]);
			} else
				throw e;
		}

		loadSymbols();
	}

	~this() {
		import std.file : remove;
		loader.unload;

		if (tempFile !is null) remove(tempFile);
	}

	private {
		void loadSymbols() {
			import cf.spew.bindings.libuv.uv;
			assert(loader.isLoaded);

			uv_version = cast(typeof(uv_version))loader.loadSymbol("uv_version");
			uv_version_string = cast(typeof(uv_version_string))loader.loadSymbol("uv_version_string");
			uv_replace_allocator = cast(typeof(uv_replace_allocator))loader.loadSymbol("uv_replace_allocator");
			uv_default_loop = cast(typeof(uv_default_loop))loader.loadSymbol("uv_default_loop");
			uv_loop_init = cast(typeof(uv_loop_init))loader.loadSymbol("uv_loop_init");
			uv_loop_close = cast(typeof(uv_loop_close))loader.loadSymbol("uv_loop_close");
			uv_loop_size = cast(typeof(uv_loop_size))loader.loadSymbol("uv_loop_size");
			uv_loop_alive = cast(typeof(uv_loop_alive))loader.loadSymbol("uv_loop_alive");
			uv_loop_configure = cast(typeof(uv_loop_configure))loader.loadSymbol("uv_loop_configure");
			uv_loop_fork = cast(typeof(uv_loop_fork))loader.loadSymbol("uv_loop_fork", false);
			uv_run = cast(typeof(uv_run))loader.loadSymbol("uv_run");
			uv_stop = cast(typeof(uv_stop))loader.loadSymbol("uv_stop");
			uv_ref = cast(typeof(uv_ref))loader.loadSymbol("uv_ref");
			uv_unref = cast(typeof(uv_unref))loader.loadSymbol("uv_unref");
			uv_has_ref = cast(typeof(uv_has_ref))loader.loadSymbol("uv_has_ref");
			uv_update_time = cast(typeof(uv_update_time))loader.loadSymbol("uv_update_time");
			uv_now = cast(typeof(uv_now))loader.loadSymbol("uv_now");
			uv_backend_fd = cast(typeof(uv_backend_fd))loader.loadSymbol("uv_backend_fd");
			uv_backend_timeout = cast(typeof(uv_backend_timeout))loader.loadSymbol("uv_backend_timeout");
			uv_translate_sys_error = cast(typeof(uv_translate_sys_error))loader.loadSymbol("uv_translate_sys_error");
			uv_strerror = cast(typeof(uv_strerror))loader.loadSymbol("uv_strerror");
			uv_err_name = cast(typeof(uv_err_name))loader.loadSymbol("uv_err_name");
			uv_shutdown = cast(typeof(uv_shutdown))loader.loadSymbol("uv_shutdown");
			uv_handle_size = cast(typeof(uv_handle_size))loader.loadSymbol("uv_handle_size");
			uv_req_size = cast(typeof(uv_req_size))loader.loadSymbol("uv_req_size");
			uv_is_active = cast(typeof(uv_is_active))loader.loadSymbol("uv_is_active");
			uv_walk = cast(typeof(uv_walk))loader.loadSymbol("uv_walk");
			uv_print_all_handles = cast(typeof(uv_print_all_handles))loader.loadSymbol("uv_print_all_handles");
			uv_print_active_handles = cast(typeof(uv_print_active_handles))loader.loadSymbol("uv_print_active_handles");
			uv_close = cast(typeof(uv_close))loader.loadSymbol("uv_close");
			uv_send_buffer_size = cast(typeof(uv_send_buffer_size))loader.loadSymbol("uv_send_buffer_size");
			uv_recv_buffer_size = cast(typeof(uv_recv_buffer_size))loader.loadSymbol("uv_recv_buffer_size");
			uv_fileno = cast(typeof(uv_fileno))loader.loadSymbol("uv_fileno");
			uv_buf_init = cast(typeof(uv_buf_init))loader.loadSymbol("uv_buf_init");
			uv_listen = cast(typeof(uv_listen))loader.loadSymbol("uv_listen");
			uv_accept = cast(typeof(uv_accept))loader.loadSymbol("uv_accept");
			uv_read_start = cast(typeof(uv_read_start))loader.loadSymbol("uv_read_start");
			uv_read_stop = cast(typeof(uv_read_stop))loader.loadSymbol("uv_read_stop");
			uv_write = cast(typeof(uv_write))loader.loadSymbol("uv_write");
			uv_write2 = cast(typeof(uv_write2))loader.loadSymbol("uv_write2");
			uv_try_write = cast(typeof(uv_try_write))loader.loadSymbol("uv_try_write");
			uv_is_readable = cast(typeof(uv_is_readable))loader.loadSymbol("uv_is_readable");
			uv_is_writable = cast(typeof(uv_is_writable))loader.loadSymbol("uv_is_writable");
			uv_stream_set_blocking = cast(typeof(uv_stream_set_blocking))loader.loadSymbol("uv_stream_set_blocking");
			uv_is_closing = cast(typeof(uv_is_closing))loader.loadSymbol("uv_is_closing");
			uv_tcp_init = cast(typeof(uv_tcp_init))loader.loadSymbol("uv_tcp_init");
			uv_tcp_init_ex = cast(typeof(uv_tcp_init_ex))loader.loadSymbol("uv_tcp_init_ex");
			uv_tcp_open = cast(typeof(uv_tcp_open))loader.loadSymbol("uv_tcp_open");
			uv_tcp_nodelay = cast(typeof(uv_tcp_nodelay))loader.loadSymbol("uv_tcp_nodelay");
			uv_tcp_keepalive = cast(typeof(uv_tcp_keepalive))loader.loadSymbol("uv_tcp_keepalive");
			uv_tcp_simultaneous_accepts = cast(typeof(uv_tcp_simultaneous_accepts))loader.loadSymbol("uv_tcp_simultaneous_accepts");
			uv_tcp_bind = cast(typeof(uv_tcp_bind))loader.loadSymbol("uv_tcp_bind");
			uv_tcp_getsockname = cast(typeof(uv_tcp_getsockname))loader.loadSymbol("uv_tcp_getsockname");
			uv_tcp_getpeername = cast(typeof(uv_tcp_getpeername))loader.loadSymbol("uv_tcp_getpeername");
			uv_tcp_connect = cast(typeof(uv_tcp_connect))loader.loadSymbol("uv_tcp_connect");
			uv_udp_init = cast(typeof(uv_udp_init))loader.loadSymbol("uv_udp_init");
			uv_udp_init_ex = cast(typeof(uv_udp_init_ex))loader.loadSymbol("uv_udp_init_ex");
			uv_udp_open = cast(typeof(uv_udp_open))loader.loadSymbol("uv_udp_open");
			uv_udp_bind = cast(typeof(uv_udp_bind))loader.loadSymbol("uv_udp_bind");
			uv_udp_getsockname = cast(typeof(uv_udp_getsockname))loader.loadSymbol("uv_udp_getsockname");
			uv_udp_set_membership = cast(typeof(uv_udp_set_membership))loader.loadSymbol("uv_udp_set_membership");
			uv_udp_set_multicast_loop = cast(typeof(uv_udp_set_multicast_loop))loader.loadSymbol("uv_udp_set_multicast_loop");
			uv_udp_set_multicast_ttl = cast(typeof(uv_udp_set_multicast_ttl))loader.loadSymbol("uv_udp_set_multicast_ttl");
			uv_udp_set_multicast_interface = cast(typeof(uv_udp_set_multicast_interface))loader.loadSymbol("uv_udp_set_multicast_interface");
			uv_udp_set_broadcast = cast(typeof(uv_udp_set_broadcast))loader.loadSymbol("uv_udp_set_broadcast");
			uv_udp_set_ttl = cast(typeof(uv_udp_set_ttl))loader.loadSymbol("uv_udp_set_ttl");
			uv_udp_send = cast(typeof(uv_udp_send))loader.loadSymbol("uv_udp_send");
			uv_udp_try_send = cast(typeof(uv_udp_try_send))loader.loadSymbol("uv_udp_try_send");
			uv_udp_recv_start = cast(typeof(uv_udp_recv_start))loader.loadSymbol("uv_udp_recv_start");
			uv_udp_recv_stop = cast(typeof(uv_udp_recv_stop))loader.loadSymbol("uv_udp_recv_stop");
			uv_tty_init = cast(typeof(uv_tty_init))loader.loadSymbol("uv_tty_init");
			uv_tty_set_mode = cast(typeof(uv_tty_set_mode))loader.loadSymbol("uv_tty_set_mode");
			uv_tty_reset_mode = cast(typeof(uv_tty_reset_mode))loader.loadSymbol("uv_tty_reset_mode");
			uv_tty_get_winsize = cast(typeof(uv_tty_get_winsize))loader.loadSymbol("uv_tty_get_winsize");
			uv_guess_handle = cast(typeof(uv_guess_handle))loader.loadSymbol("uv_guess_handle");
			uv_pipe_init = cast(typeof(uv_pipe_init))loader.loadSymbol("uv_pipe_init");
			uv_pipe_open = cast(typeof(uv_pipe_open))loader.loadSymbol("uv_pipe_open");
			uv_pipe_bind = cast(typeof(uv_pipe_bind))loader.loadSymbol("uv_pipe_bind");
			uv_pipe_connect = cast(typeof(uv_pipe_connect))loader.loadSymbol("uv_pipe_connect");
			uv_pipe_getsockname = cast(typeof(uv_pipe_getsockname))loader.loadSymbol("uv_pipe_getsockname");
			uv_pipe_getpeername = cast(typeof(uv_pipe_getpeername))loader.loadSymbol("uv_pipe_getpeername");
			uv_pipe_pending_instances = cast(typeof(uv_pipe_pending_instances))loader.loadSymbol("uv_pipe_pending_instances");
			uv_pipe_pending_count = cast(typeof(uv_pipe_pending_count))loader.loadSymbol("uv_pipe_pending_count");
			uv_pipe_pending_type = cast(typeof(uv_pipe_pending_type))loader.loadSymbol("uv_pipe_pending_type");
			uv_poll_init = cast(typeof(uv_poll_init))loader.loadSymbol("uv_poll_init");
			uv_poll_init_socket = cast(typeof(uv_poll_init_socket))loader.loadSymbol("uv_poll_init_socket");
			uv_poll_start = cast(typeof(uv_poll_start))loader.loadSymbol("uv_poll_start");
			uv_poll_stop = cast(typeof(uv_poll_stop))loader.loadSymbol("uv_poll_stop");
			uv_prepare_init = cast(typeof(uv_prepare_init))loader.loadSymbol("uv_prepare_init");
			uv_prepare_start = cast(typeof(uv_prepare_start))loader.loadSymbol("uv_prepare_start");
			uv_prepare_stop = cast(typeof(uv_prepare_stop))loader.loadSymbol("uv_prepare_stop");
			uv_check_init = cast(typeof(uv_check_init))loader.loadSymbol("uv_check_init");
			uv_check_start = cast(typeof(uv_check_start))loader.loadSymbol("uv_check_start");
			uv_check_stop = cast(typeof(uv_check_stop))loader.loadSymbol("uv_check_stop");
			uv_idle_init = cast(typeof(uv_idle_init))loader.loadSymbol("uv_idle_init");
			uv_idle_start = cast(typeof(uv_idle_start))loader.loadSymbol("uv_idle_start");
			uv_idle_stop = cast(typeof(uv_idle_stop))loader.loadSymbol("uv_idle_stop");
			uv_async_init = cast(typeof(uv_async_init))loader.loadSymbol("uv_async_init");
			uv_async_send = cast(typeof(uv_async_send))loader.loadSymbol("uv_async_send");
			uv_timer_init = cast(typeof(uv_timer_init))loader.loadSymbol("uv_timer_init");
			uv_timer_start = cast(typeof(uv_timer_start))loader.loadSymbol("uv_timer_start");
			uv_timer_stop = cast(typeof(uv_timer_stop))loader.loadSymbol("uv_timer_stop");
			uv_timer_again = cast(typeof(uv_timer_again))loader.loadSymbol("uv_timer_again");
			uv_timer_set_repeat = cast(typeof(uv_timer_set_repeat))loader.loadSymbol("uv_timer_set_repeat");
			uv_timer_get_repeat = cast(typeof(uv_timer_get_repeat))loader.loadSymbol("uv_timer_get_repeat");
			uv_getaddrinfo = cast(typeof(uv_getaddrinfo))loader.loadSymbol("uv_getaddrinfo");
			uv_freeaddrinfo = cast(typeof(uv_freeaddrinfo))loader.loadSymbol("uv_freeaddrinfo");
			uv_getnameinfo = cast(typeof(uv_getnameinfo))loader.loadSymbol("uv_getnameinfo");
			uv_spawn = cast(typeof(uv_spawn))loader.loadSymbol("uv_spawn");
			uv_process_kill = cast(typeof(uv_process_kill))loader.loadSymbol("uv_process_kill");
			uv_kill = cast(typeof(uv_kill))loader.loadSymbol("uv_kill");
			uv_queue_work = cast(typeof(uv_queue_work))loader.loadSymbol("uv_queue_work");
			uv_cancel = cast(typeof(uv_cancel))loader.loadSymbol("uv_cancel");
			uv_setup_args = cast(typeof(uv_setup_args))loader.loadSymbol("uv_setup_args");
			uv_get_process_title = cast(typeof(uv_get_process_title))loader.loadSymbol("uv_get_process_title");
			uv_set_process_title = cast(typeof(uv_set_process_title))loader.loadSymbol("uv_set_process_title");
			uv_resident_set_memory = cast(typeof(uv_resident_set_memory))loader.loadSymbol("uv_resident_set_memory");
			uv_uptime = cast(typeof(uv_uptime))loader.loadSymbol("uv_uptime");
			uv_get_osfhandle = cast(typeof(uv_get_osfhandle))loader.loadSymbol("uv_get_osfhandle", false);
			uv_getrusage = cast(typeof(uv_getrusage))loader.loadSymbol("uv_getrusage");
			uv_os_homedir = cast(typeof(uv_os_homedir))loader.loadSymbol("uv_os_homedir");
			uv_os_tmpdir = cast(typeof(uv_os_tmpdir))loader.loadSymbol("uv_os_tmpdir");
			uv_os_get_passwd = cast(typeof(uv_os_get_passwd))loader.loadSymbol("uv_os_get_passwd");
			uv_os_free_passwd = cast(typeof(uv_os_free_passwd))loader.loadSymbol("uv_os_free_passwd");
			uv_cpu_info = cast(typeof(uv_cpu_info))loader.loadSymbol("uv_cpu_info");
			uv_free_cpu_info = cast(typeof(uv_free_cpu_info))loader.loadSymbol("uv_free_cpu_info");
			uv_interface_addresses = cast(typeof(uv_interface_addresses))loader.loadSymbol("uv_interface_addresses");
			uv_free_interface_addresses = cast(typeof(uv_free_interface_addresses))loader.loadSymbol("uv_free_interface_addresses");
			uv_os_getenv = cast(typeof(uv_os_getenv))loader.loadSymbol("uv_os_getenv", false);
			uv_os_setenv = cast(typeof(uv_os_setenv))loader.loadSymbol("uv_os_setenv", false);
			uv_os_unsetenv = cast(typeof(uv_os_unsetenv))loader.loadSymbol("uv_os_unsetenv", false);
			uv_os_gethostname = cast(typeof(uv_os_gethostname))loader.loadSymbol("uv_os_gethostname", false);
			uv_fs_req_cleanup = cast(typeof(uv_fs_req_cleanup))loader.loadSymbol("uv_fs_req_cleanup");
			uv_fs_close = cast(typeof(uv_fs_close))loader.loadSymbol("uv_fs_close");
			uv_fs_open = cast(typeof(uv_fs_open))loader.loadSymbol("uv_fs_open");
			uv_fs_read = cast(typeof(uv_fs_read))loader.loadSymbol("uv_fs_read");
			uv_fs_unlink = cast(typeof(uv_fs_unlink))loader.loadSymbol("uv_fs_unlink");
			uv_fs_write = cast(typeof(uv_fs_write))loader.loadSymbol("uv_fs_write");
			uv_fs_copyfile = cast(typeof(uv_fs_copyfile))loader.loadSymbol("uv_fs_copyfile", false);
			uv_fs_mkdir = cast(typeof(uv_fs_mkdir))loader.loadSymbol("uv_fs_mkdir");
			uv_fs_mkdtemp = cast(typeof(uv_fs_mkdtemp))loader.loadSymbol("uv_fs_mkdtemp");
			uv_fs_rmdir = cast(typeof(uv_fs_rmdir))loader.loadSymbol("uv_fs_rmdir");
			uv_fs_scandir = cast(typeof(uv_fs_scandir))loader.loadSymbol("uv_fs_scandir");
			uv_fs_scandir_next = cast(typeof(uv_fs_scandir_next))loader.loadSymbol("uv_fs_scandir_next");
			uv_fs_stat = cast(typeof(uv_fs_stat))loader.loadSymbol("uv_fs_stat");
			uv_fs_fstat = cast(typeof(uv_fs_fstat))loader.loadSymbol("uv_fs_fstat");
			uv_fs_rename = cast(typeof(uv_fs_rename))loader.loadSymbol("uv_fs_rename");
			uv_fs_fsync = cast(typeof(uv_fs_fsync))loader.loadSymbol("uv_fs_fsync");
			uv_fs_fdatasync = cast(typeof(uv_fs_fdatasync))loader.loadSymbol("uv_fs_fdatasync");
			uv_fs_ftruncate = cast(typeof(uv_fs_ftruncate))loader.loadSymbol("uv_fs_ftruncate");
			uv_fs_sendfile = cast(typeof(uv_fs_sendfile))loader.loadSymbol("uv_fs_sendfile");
			uv_fs_access = cast(typeof(uv_fs_access))loader.loadSymbol("uv_fs_access");
			uv_fs_chmod = cast(typeof(uv_fs_chmod))loader.loadSymbol("uv_fs_chmod");
			uv_fs_utime = cast(typeof(uv_fs_utime))loader.loadSymbol("uv_fs_utime");
			uv_fs_futime = cast(typeof(uv_fs_futime))loader.loadSymbol("uv_fs_futime");
			uv_fs_lstat = cast(typeof(uv_fs_lstat))loader.loadSymbol("uv_fs_lstat");
			uv_fs_link = cast(typeof(uv_fs_link))loader.loadSymbol("uv_fs_link");
			uv_fs_symlink = cast(typeof(uv_fs_symlink))loader.loadSymbol("uv_fs_symlink");
			uv_fs_readlink = cast(typeof(uv_fs_readlink))loader.loadSymbol("uv_fs_readlink");
			uv_fs_realpath = cast(typeof(uv_fs_realpath))loader.loadSymbol("uv_fs_realpath");
			uv_fs_fchmod = cast(typeof(uv_fs_fchmod))loader.loadSymbol("uv_fs_fchmod");
			uv_fs_chown = cast(typeof(uv_fs_chown))loader.loadSymbol("uv_fs_chown");
			uv_fs_fchown = cast(typeof(uv_fs_fchown))loader.loadSymbol("uv_fs_fchown");
			uv_fs_poll_init = cast(typeof(uv_fs_poll_init))loader.loadSymbol("uv_fs_poll_init");
			uv_fs_poll_start = cast(typeof(uv_fs_poll_start))loader.loadSymbol("uv_fs_poll_start");
			uv_fs_poll_stop = cast(typeof(uv_fs_poll_stop))loader.loadSymbol("uv_fs_poll_stop");
			uv_fs_poll_getpath = cast(typeof(uv_fs_poll_getpath))loader.loadSymbol("uv_fs_poll_getpath");
			uv_signal_init = cast(typeof(uv_signal_init))loader.loadSymbol("uv_signal_init");
			uv_signal_start = cast(typeof(uv_signal_start))loader.loadSymbol("uv_signal_start");
			uv_signal_start_oneshot = cast(typeof(uv_signal_start_oneshot))loader.loadSymbol("uv_signal_start_oneshot", false);
			uv_signal_stop = cast(typeof(uv_signal_stop))loader.loadSymbol("uv_signal_stop");
			uv_loadavg = cast(typeof(uv_loadavg))loader.loadSymbol("uv_loadavg");
			uv_fs_event_init = cast(typeof(uv_fs_event_init))loader.loadSymbol("uv_fs_event_init");
			uv_fs_event_start = cast(typeof(uv_fs_event_start))loader.loadSymbol("uv_fs_event_start");
			uv_fs_event_stop = cast(typeof(uv_fs_event_stop))loader.loadSymbol("uv_fs_event_stop");
			uv_fs_event_getpath = cast(typeof(uv_fs_event_getpath))loader.loadSymbol("uv_fs_event_getpath");
			uv_ip4_addr = cast(typeof(uv_ip4_addr))loader.loadSymbol("uv_ip4_addr");
			uv_ip6_addr = cast(typeof(uv_ip6_addr))loader.loadSymbol("uv_ip6_addr");
			uv_ip4_name = cast(typeof(uv_ip4_name))loader.loadSymbol("uv_ip4_name");
			uv_ip6_name = cast(typeof(uv_ip6_name))loader.loadSymbol("uv_ip6_name");
			uv_inet_ntop = cast(typeof(uv_inet_ntop))loader.loadSymbol("uv_inet_ntop");
			uv_inet_pton = cast(typeof(uv_inet_pton))loader.loadSymbol("uv_inet_pton");
			uv_exepath = cast(typeof(uv_exepath))loader.loadSymbol("uv_exepath");
			uv_cwd = cast(typeof(uv_cwd))loader.loadSymbol("uv_cwd");
			uv_chdir = cast(typeof(uv_chdir))loader.loadSymbol("uv_chdir");
			uv_get_free_memory = cast(typeof(uv_get_free_memory))loader.loadSymbol("uv_get_free_memory");
			uv_get_total_memory = cast(typeof(uv_get_total_memory))loader.loadSymbol("uv_get_total_memory");
			uv_hrtime = cast(typeof(uv_hrtime))loader.loadSymbol("uv_hrtime");
			uv_disable_stdio_inheritance = cast(typeof(uv_disable_stdio_inheritance))loader.loadSymbol("uv_disable_stdio_inheritance");
			uv_dlopen = cast(typeof(uv_dlopen))loader.loadSymbol("uv_dlopen");
			uv_dlclose = cast(typeof(uv_dlclose))loader.loadSymbol("uv_dlclose");
			uv_dlsym = cast(typeof(uv_dlsym))loader.loadSymbol("uv_dlsym");
			uv_dlerror = cast(typeof(uv_dlerror))loader.loadSymbol("uv_dlerror");
			uv_mutex_init = cast(typeof(uv_mutex_init))loader.loadSymbol("uv_mutex_init");
			uv_mutex_destroy = cast(typeof(uv_mutex_destroy))loader.loadSymbol("uv_mutex_destroy");
			uv_mutex_lock = cast(typeof(uv_mutex_lock))loader.loadSymbol("uv_mutex_lock");
			uv_mutex_trylock = cast(typeof(uv_mutex_trylock))loader.loadSymbol("uv_mutex_trylock");
			uv_mutex_unlock = cast(typeof(uv_mutex_unlock))loader.loadSymbol("uv_mutex_unlock");
			uv_rwlock_init = cast(typeof(uv_rwlock_init))loader.loadSymbol("uv_rwlock_init");
			uv_rwlock_destroy = cast(typeof(uv_rwlock_destroy))loader.loadSymbol("uv_rwlock_destroy");
			uv_rwlock_rdlock = cast(typeof(uv_rwlock_rdlock))loader.loadSymbol("uv_rwlock_rdlock");
			uv_rwlock_tryrdlock = cast(typeof(uv_rwlock_tryrdlock))loader.loadSymbol("uv_rwlock_tryrdlock");
			uv_rwlock_rdunlock = cast(typeof(uv_rwlock_rdunlock))loader.loadSymbol("uv_rwlock_rdunlock");
			uv_rwlock_wrlock = cast(typeof(uv_rwlock_wrlock))loader.loadSymbol("uv_rwlock_wrlock");
			uv_rwlock_trywrlock = cast(typeof(uv_rwlock_trywrlock))loader.loadSymbol("uv_rwlock_trywrlock");
			uv_rwlock_wrunlock = cast(typeof(uv_rwlock_wrunlock))loader.loadSymbol("uv_rwlock_wrunlock");
			uv_sem_init = cast(typeof(uv_sem_init))loader.loadSymbol("uv_sem_init");
			uv_sem_destroy = cast(typeof(uv_sem_destroy))loader.loadSymbol("uv_sem_destroy");
			uv_sem_post = cast(typeof(uv_sem_post))loader.loadSymbol("uv_sem_post");
			uv_sem_wait = cast(typeof(uv_sem_wait))loader.loadSymbol("uv_sem_wait");
			uv_sem_trywait = cast(typeof(uv_sem_trywait))loader.loadSymbol("uv_sem_trywait");
			uv_cond_init = cast(typeof(uv_cond_init))loader.loadSymbol("uv_cond_init");
			uv_cond_destroy = cast(typeof(uv_cond_destroy))loader.loadSymbol("uv_cond_destroy");
			uv_cond_signal = cast(typeof(uv_cond_signal))loader.loadSymbol("uv_cond_signal");
			uv_cond_broadcast = cast(typeof(uv_cond_broadcast))loader.loadSymbol("uv_cond_broadcast");
			uv_barrier_init = cast(typeof(uv_barrier_init))loader.loadSymbol("uv_barrier_init");
			uv_barrier_destroy = cast(typeof(uv_barrier_destroy))loader.loadSymbol("uv_barrier_destroy");
			uv_barrier_wait = cast(typeof(uv_barrier_wait))loader.loadSymbol("uv_barrier_wait");
			uv_cond_wait = cast(typeof(uv_cond_wait))loader.loadSymbol("uv_cond_wait");
			uv_cond_timedwait = cast(typeof(uv_cond_timedwait))loader.loadSymbol("uv_cond_timedwait");
			uv_once = cast(typeof(uv_once))loader.loadSymbol("uv_once");
			uv_key_create = cast(typeof(uv_key_create))loader.loadSymbol("uv_key_create");
			uv_key_delete = cast(typeof(uv_key_delete))loader.loadSymbol("uv_key_delete");
			uv_key_get = cast(typeof(uv_key_get))loader.loadSymbol("uv_key_get");
			uv_key_set = cast(typeof(uv_key_set))loader.loadSymbol("uv_key_set");
			uv_thread_create = cast(typeof(uv_thread_create))loader.loadSymbol("uv_thread_create");
			uv_thread_self = cast(typeof(uv_thread_self))loader.loadSymbol("uv_thread_self");
			uv_thread_join = cast(typeof(uv_thread_join))loader.loadSymbol("uv_thread_join");
			uv_thread_equal = cast(typeof(uv_thread_equal))loader.loadSymbol("uv_thread_equal");
		}
	}
}