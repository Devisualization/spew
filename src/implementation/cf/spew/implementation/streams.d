module cf.spew.implementation.streams;
import cf.spew.streams.defs;
import cf.spew.bindings.libuv.uv;
import std.socket : Address, InternetAddress, Internet6Address, AddressFamily, sockaddr;
import std.experimental.allocator : IAllocator, theAllocator, make, makeArray, expandArray, dispose;
import std.experimental.memory.managed;
import core.time;

private {
	AnStreamEndPoint clientLL;
	AnStreamServer serverLL;

	static ~this() {
		closeAllInstances();
	}
}

void closeAllInstances() {
	auto client = cast(AnStreamEndPoint)clientLL;
	auto server = cast(AnStreamServer)serverLL;
	
	while(client !is null) {
		if (client.isOpen)
			client.close;
		client = client.next;
	}
	while(server !is null) {
		if (server.isOpen)
			server.close;
		server = server.next;
	}
	
	clientLL = null;
	serverLL = null;
}

class LibUVStreamCreator : IStreamCreator {
	private {
		StreamType type;
		IAllocator alloc;

		bool tcp_nodelay_;
		Duration tcp_timeout_ = Duration.zero;

		OnStreamDataDel onData_;
		OnStreamLifeDel onClose_, onCreate_;
	}

	this(StreamType type, IAllocator alloc) {
		this.type = type;
		this.alloc = alloc;
	}

	void tcp_nodelay(bool v) { tcp_nodelay_ = v; }
	void tcp_keepAliveTimeout(Duration duration) { tcp_timeout_ = duration; }

	@property {
		void onData(OnStreamDataDel callback) { onData_ = callback; }
		void onStreamCreate(OnStreamLifeDel callback) { onCreate_ = callback; }
		void onStreamClose(OnStreamLifeDel callback) { onClose_ = callback; }
	}

	managed!IStreamEndpoint connectClient(scope Address addr) {
		import cf.spew.event_loop.wells.libuv;
		AnStreamEndPoint ret;

		if (type == StreamType.TCP) {
			auto temp = alloc.make!LibUVStreamEndpoint(type, null, alloc);

			if (addr.addressFamily == AddressFamily.INET) {
				(*cast(sockaddr_in*)&temp.addrstorage) = *cast(sockaddr_in*)addr.name();
			} else if (addr.addressFamily == AddressFamily.INET6) {
				(*cast(sockaddr_in6*)&temp.addrstorage) = *cast(sockaddr_in6*)addr.name();
			}

			auto seconds = tcp_timeout_.total!"seconds";
			if (seconds > 0) uv_tcp_keepalive(&temp.ctx_tcp, 1, cast(uint)seconds);

			uv_tcp_nodelay(&temp.ctx_tcp, tcp_nodelay_ ? 1 : 0);
			uv_tcp_connect(&temp.uv_connect, &temp.ctx_tcp, cast(sockaddr*)&temp.addrstorage, &streamEndPointCreateCB);

			ret = temp;
		} else if (type == StreamType.UDP) {
			/+auto temp = alloc.make!LibUVStreamEndpoint(type, null, alloc);
			
			ret = temp;+/
			assert(0, "Not implemented");
		}

		if (ret is null) return managed!IStreamEndpoint.init;
		ret.next = clientLL;
		clientLL = ret.next;

		ret.onCreate_ = onCreate_;
		ret.onClose_ = onClose_;
		ret.onData_ = onData_;
		return cast(managed!IStreamEndpoint)managed!AnStreamEndPoint(ret, managers(), alloc);
	}

	managed!IStreamServer bindServer(scope Address addr) {
		AnStreamServer ret;



		if (ret is null) {
			return managed!IStreamServer.init;
		}
		
		ret.next = serverLL;
		serverLL = ret.next;
		
		return cast(managed!IStreamServer)managed!AnStreamServer(ret, managers(), alloc);
	}
}

abstract class AnStreamEndPoint : IStreamEndpoint {
	AnStreamEndPoint next;
	StreamType _type;
	IStreamServer _server;
	IAllocator alloc;

	OnStreamDataDel onData_;
	OnStreamLifeDel onClose_, onCreate_;

	this(StreamType type, IStreamServer server, IAllocator alloc) {
		_type = type;
		_server = server;
		this.alloc = alloc;
	}

	~this() {
		if (_server is null) {
			AnStreamEndPoint last,
				current = clientLL;
			while(current !is null) {
				if (current is this) {
					if (last is null) {
						clientLL = current.next;
						break;
					} else {
						last.next = current.next;
						break;
					}
				}

				last = current;
				current = current.next;
			}
		}

	}
}

abstract class AnStreamServer : IStreamServer {
	AnStreamServer next;
	StreamType _type;
	IAllocator alloc;
	
	this(StreamType type, IAllocator alloc) {
		_type = type;
		this.alloc = alloc;
	}

	~this() {
		AnStreamServer last,
			current = serverLL;
		while(current !is null) {
			if (current is this) {
				if (last is null) {
					serverLL = current.next;
					break;
				} else {
					last.next = current.next;
					break;
				}
			}
			
			last = current;
			current = current.next;
		}
	}
}

class LibUVStreamEndpoint : AnStreamEndPoint {
	private {
		bool isClosed;
		LibUVStreamEndpoint self;
		LibUVWriteLL[] allWriteLL;
		LibUVWriteLL* writeLLFreeList;
		sockaddr_storage addrstorage;
	}

	union {
		uv_stream_t ctx;
		uv_tcp_t ctx_tcp;
		uv_udp_t ctx_udp;
	}

	uv_connect_t uv_connect;
	sockaddr* udp_remote_addr;

	this(StreamType type, IStreamServer server, IAllocator alloc) {
		import cf.spew.event_loop.wells.libuv;
		super(type, server, alloc);
		self = this;

		if (type == StreamType.TCP) {
			uv_tcp_init(getThreadLoop_UV(), &ctx_tcp);
		} else if (type == StreamType.UDP) {
			uv_udp_init(getThreadLoop_UV(), &ctx_udp);
		} else assert(0);

		ctx.data = &self;
	}

	~this() {
		if (isOpen)
			close();
		alloc.dispose(allWriteLL);
	}

	void write(ubyte[] data...) {
		if (!writable) return;
		LibUVWriteLL* theLL;

		if (writeLLFreeList is null) {
			if (allWriteLL.length == 0)
				allWriteLL = alloc.makeArray!LibUVWriteLL(8);
			else
				alloc.expandArray(allWriteLL, 8);
			foreach_reverse(ref v; allWriteLL[$-7 .. $]) {
				v.next = writeLLFreeList;
				v.endpoint = this;
				writeLLFreeList = &v;
			}
			theLL = &allWriteLL[$-1];
			theLL.endpoint = this;
		} else {
			theLL = writeLLFreeList;
			writeLLFreeList = theLL.next;
			theLL.next = null;

			theLL.req = uv_write_t.init;
		}

		ubyte[] data2 = alloc.makeArray!ubyte(data.length);
		data2[] = data[];

		theLL.req.data = theLL;
		theLL.buf = uv_buf_init(cast(char*)data2.ptr, cast(uint)data2.length);
		uv_write(&theLL.req, &ctx, cast(const)&theLL.buf, 1, &streamEndPointWriteCB);
	}

	void onData(OnStreamDataDel callback) { onData_ = callback; }
	void onStreamClose(OnStreamLifeDel callback) { onClose_ = callback; }
	
	@property {
		StreamType type() { return _type; }
		IStreamServer server() { return _server; }

		bool readable() {
			if (!isOpen) return false;
			return uv_is_readable(&ctx) == 1;
		}

		bool writable() {
			if (!isOpen) return false;
			return uv_is_writable(&ctx) == 1;
		}
	}

	managed!Address localAddress(IAllocator alloc=theAllocator()) {
		if (!isOpen) return managed!Address.init;

		// 0 .. 15 == ipv4
		// 0 .. 39 == ipv6 
		sockaddr_storage addr;
		int alen = sockaddr_storage.sizeof;

		if (_type == StreamType.TCP) {
			if (uv_tcp_getsockname(&ctx_tcp, cast(sockaddr*)&addr, &alen) != 0) {
			} else if (addr.ss_family == AF_INET) {
				return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
			} else if (addr.ss_family == AF_INET6) {
				return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
			}
		} else if (_type == StreamType.UDP) {
			if (uv_udp_getsockname(&ctx_udp, cast(sockaddr*)&addr, &alen) != 0) {
			} else if (addr.ss_family == AF_INET) {
				return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
			} else if (addr.ss_family == AF_INET6) {
				return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
			}
		}

		return managed!Address.init;
	}

	managed!Address remoteAddress(IAllocator alloc=theAllocator()) {
		if (!isOpen) return managed!Address.init;
		
		// 0 .. 15 == ipv4
		// 0 .. 39 == ipv6 
		sockaddr_storage addr;
		int alen = sockaddr_storage.sizeof;
		
		if (_type == StreamType.TCP) {
			if (uv_tcp_getpeername(&ctx_tcp, cast(sockaddr*)&addr, &alen) != 0) {
			} else if (addr.ss_family == AF_INET) {
				return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
			} else if (addr.ss_family == AF_INET6) {
				return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
			}
		} else if (_type == StreamType.UDP) {
			if (udp_remote_addr is null) {
			} else if (udp_remote_addr.sa_family == AF_INET) {
				return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)udp_remote_addr), managers(), alloc);
			} else if (udp_remote_addr.sa_family == AF_INET6) {
				return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)udp_remote_addr), managers(), alloc);
			}
		}
		
		return managed!Address.init;
	}

	bool isOpen() { return !isClosed; }

	void close() {
		uv_read_stop(&ctx);
		uv_close(cast(uv_handle_t*)&ctx, &streamEndPointCloseCB);
	}
}

extern(C) {
	void streamEndPointCreateCB(uv_connect_t* connection, int status) {
		LibUVStreamEndpoint ctx = *cast(LibUVStreamEndpoint*)connection.handle.data;

		uv_read_start(&ctx.ctx, &streamAllocCB, &streamEndPointReadCB);

		if (ctx.onCreate_ !is null)
			ctx.onCreate_(ctx);
	}
	
	void streamAllocCB(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
		LibUVStreamEndpoint ctx = *cast(LibUVStreamEndpoint*)handle.data;
		buf.base = ctx.alloc.makeArray!char(suggested_size).ptr;
		buf.len = suggested_size;
	}

	void streamEndPointReadCB(uv_stream_t* client, ptrdiff_t nread, const(uv_buf_t)* buf) {
		LibUVStreamEndpoint ctx = *cast(LibUVStreamEndpoint*)client.data;

		if (ctx.onData_ !is null) {
			if (nread > 0 && ctx.onData_(ctx, cast(ubyte[])buf.base[0 .. cast(size_t)nread])) {}
			else ctx.close();
		} else if (nread < 0)
			ctx.close();

		ctx.alloc.dispose(cast(char[])buf.base[0 .. buf.len]);
	}

	void streamEndPointCloseCB(uv_handle_t* handle, int status) {
		auto ctx = *cast(LibUVStreamEndpoint*)handle.data;

		ctx.isClosed = true;
		if (ctx.onClose_ !is null)
			ctx.onClose_(ctx);
	}

	void streamEndPointWriteCB(uv_write_t* req, int status) {
		auto ctx = cast(LibUVWriteLL*)req.data;

		ctx.next = ctx.endpoint.writeLLFreeList;
		ctx.endpoint.writeLLFreeList = ctx;

		ctx.endpoint.alloc.dispose(cast(ubyte[])ctx.buf.base[0 .. ctx.buf.len]);
	}
}

private {
	struct LibUVWriteLL {
		LibUVWriteLL* next;
		LibUVStreamEndpoint endpoint;
		uv_write_t req;
		uv_buf_t buf;
	}
}