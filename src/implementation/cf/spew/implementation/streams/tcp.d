/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.streams.tcp;
import cf.spew.implementation.streams.base;
import cf.spew.streams.defs;
import cf.spew.streams.tcp;
import devisualization.util.core.memory.managed;
import devisualization.bindings.libuv.uv;
import std.experimental.allocator : IAllocator, theAllocator, make, dispose, makeArray;
import std.socket : Address, AddressFamily, sockaddr, InternetAddress, Internet6Address;
import core.time : Duration;

abstract class AnTCPSocket : StreamPoint, ISocket_TCP {
	private {
		ISocket_TCPServer server_;
		IAllocator alloc;
	}

	@property {
		ISocket_TCPServer server() { return server_; }

		// *sigh* just why is this required?
		override void onConnect(OnStreamConnectedDel callback) { onStreamConnectedDel = callback; }
	}
}

class LibUVTCPSocket : AnTCPSocket {
	@property {
		void blocking(bool v) {
			if (!isOpen) return;

			uv_stream_set_blocking(&ctx_stream, v ? 1 : 0);
		}

		void noDelay(bool v) {
			if (!isOpen) return;

			uv_tcp_nodelay(&ctx_tcp, v ? 1 : 0);
		}
		
		void keepAliveTimeout(Duration duration) {
			if (!isOpen) return;

			auto seconds = duration.total!"seconds";
			if (seconds > 0) uv_tcp_keepalive(&ctx_tcp, 1, cast(uint)seconds);
			else uv_tcp_keepalive(&ctx_tcp, 0, 0);
		}

		bool isOpen() { return !hasBeenClosed; }

		bool writable() {
			if (!isOpen) return false;
			return uv_is_writable(&ctx_stream) == 1;
		}

		bool readable() {
			if (!isOpen) return false;
			return uv_is_readable(&ctx_stream) == 1;
		}
	}

	// should be package(cf.spew.implementation)
	this(ISocket_TCPServer server, IAllocator alloc) {
		import cf.spew.event_loop.wells.libuv;
		this.alloc = alloc;
		this.server_ = server;
		self = this;

		uv_tcp_init(getThreadLoop_UV(), &ctx_tcp);
		ctx_tcp.data = &self;
	}

	~this() {
		if (isOpen) {
			ctx_tcp.data = null;
			close();
		}
	}

	package(cf.spew.implementation) {
		bool hasBeenClosed;
		LibUVTCPSocket self;
		sockaddr_storage addrstorage;

		uv_connect_t uv_connect;
		union {
			uv_handle_t ctx_handle;
			uv_stream_t ctx_stream;
			uv_tcp_t ctx_tcp;
		}

		void startAccept() {
			if (!isOpen) return;
			uv_read_start(&ctx_stream, &streamTCPAllocCB, &streamTCPReadCB);
		}
	}

	static managed!ISocket_TCP create(Address address, IAllocator alloc=theAllocator()) {
		if (address is null || alloc is null) return managed!ISocket_TCP.init;
		auto ret = alloc.make!LibUVTCPSocket(null, alloc);
		
		if (address.addressFamily == AddressFamily.INET) {
			(*cast(sockaddr_in*)&ret.addrstorage) = *cast(sockaddr_in*)address.name();
		} else if (address.addressFamily == AddressFamily.INET6) {
			(*cast(sockaddr_in6*)&ret.addrstorage) = *cast(sockaddr_in6*)address.name();
		} else assert(0, "Unknown address format");

		if (uv_tcp_connect(&ret.uv_connect, &ret.ctx_tcp, cast(sockaddr*)&ret.addrstorage, &streamTCPCreateCB) != 0) {
			alloc.dispose(ret);
			return managed!ISocket_TCP.init;
		}

		ret.addToLifeLL();
		return cast(managed!ISocket_TCP)managed!LibUVTCPSocket(ret, managers(), alloc);
	}

	void write(const(ubyte[]) data...) {
		import core.memory : GC;

		LibUVWriteTCP* writebuf = alloc.make!LibUVWriteTCP;
		GC.removeRoot(writebuf);

		writebuf.req.data = writebuf;
		writebuf.self = this;

		char* buffer = alloc.makeArray!char(data.length).ptr;
		GC.removeRoot(buffer);

		buffer[0 .. data.length] = cast(char[])data[];

		assert(data.length < uint.max, "Too big of data to write, limit uint.max");
		writebuf.buf = uv_buf_init(buffer, cast(uint)data.length);
		uv_write(&writebuf.req, &ctx_stream, cast(const)&writebuf.buf, 1, &streamTCPWriteCB);
	}

	managed!Address localAddress(IAllocator alloc=theAllocator()) {
		sockaddr_storage addr;
		int alen = sockaddr_storage.sizeof;

		if (!isOpen || uv_tcp_getsockname(&ctx_tcp, cast(sockaddr*)&addr, &alen) != 0) {
		} else if (addr.ss_family == AF_INET) {
			return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
		} else if (addr.ss_family == AF_INET6) {
			return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
		}

		return managed!Address.init;
	}

	managed!Address remoteAddress(IAllocator alloc=theAllocator()) {
		sockaddr_storage addr;
		int alen = sockaddr_storage.sizeof;

		if (!isOpen || uv_tcp_getpeername(&ctx_tcp, cast(sockaddr*)&addr, &alen) != 0) {
		} else if (addr.ss_family == AF_INET) {
			return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
		} else if (addr.ss_family == AF_INET6) {
			return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
		}

		return managed!Address.init;
	}

	void close() {
		if (!isOpen) return;

		uv_read_stop(&ctx_stream);
		uv_close(&ctx_handle, &streamTCPCloseCB);
	}
}

private {
	struct LibUVWriteTCP {
		LibUVTCPSocket self;
		uv_write_t req;
		uv_buf_t buf;
	}
}

extern(C) {
	void streamTCPCreateCB(uv_connect_t* connection, int status) {
		LibUVTCPSocket ctx = *cast(LibUVTCPSocket*)connection.handle.data;
		assert(ctx !is null);
		ctx.startAccept();
		if (ctx.onStreamConnectedDel !is null)
			ctx.onStreamConnectedDel(ctx);
	}

	void streamTCPCloseCB(uv_handle_t* handle, int status) {
		if (handle.data is null) return;
		auto self = *cast(LibUVTCPSocket*)handle.data;
		
		if (self.hasBeenClosed) return;
		self.hasBeenClosed = true;

		if (self.onStreamCloseDel !is null)
			self.onStreamCloseDel(self);
	}

	void streamTCPAllocCB(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
		import core.memory : GC;

		if (handle.data is null) return;
		auto self = *cast(LibUVTCPSocket*)handle.data;

		buf.base = self.alloc.makeArray!char(suggested_size).ptr;
		GC.removeRoot(buf.base);
		buf.len = suggested_size;
	}

	void streamTCPReadCB(uv_stream_t* client, ptrdiff_t nread, const(uv_buf_t)* buf) {
		if (client.data is null) return;
		auto self = *cast(LibUVTCPSocket*)client.data;

		if (self.onDataDel !is null) {
			if (nread > 0 && self.onDataDel(self, cast(ubyte[])buf.base[0 .. cast(size_t)nread])) {}
			else self.close();
		} else if (nread < 0) self.close();

		self.alloc.dispose(cast(char[])buf.base[0 .. buf.len]);
	}

	void streamTCPWriteCB(uv_write_t* req, int status) {
		auto writebuf = cast(LibUVWriteTCP*)req.data;

		writebuf.self.alloc.dispose(cast(ubyte[])writebuf.buf.base[0 .. writebuf.buf.len]);
		writebuf.self.alloc.dispose(writebuf);
	}
}