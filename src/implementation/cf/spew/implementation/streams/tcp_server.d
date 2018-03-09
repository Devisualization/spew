/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.streams.tcp_server;
import cf.spew.implementation.streams.tcp;
import cf.spew.implementation.streams.base;
import cf.spew.streams.defs;
import cf.spew.streams.tcp;
import devisualization.bindings.libuv;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, theAllocator, make, dispose;
import std.socket : Address, AddressFamily, sockaddr, InternetAddress, Internet6Address;
import core.time : Duration;

abstract class AnTCPServer : StreamPoint, ISocket_TCPServer {
	private ushort listBacklogAmount_ = 128;
}

class LibUVTCPServer : AnTCPServer {
	package(cf.spew.implementation) {
		bool hasBeenClosed;
		LibUVTCPServer self;
		IAllocator alloc;

		sockaddr_storage addrstorage;

		union {
			uv_handle_t ctx_handle;
			uv_stream_t ctx_stream;
			uv_tcp_t ctx_tcp;
		}
	}

	this(ushort listBacklogAmount, IAllocator alloc) {
		import cf.spew.event_loop.wells.libuv;
		self = this;
		this.alloc = alloc;

		libuv.uv_tcp_init(getThreadLoop_UV(), &ctx_tcp);
		ctx_tcp.data = &self;
	}

	~this() {
		if (isOpen) close();
	}

	@property {
		void blocking(bool v) {
			if (!isOpen) return;
			libuv.uv_stream_set_blocking(&ctx_stream, v ? 1 : 0);
		}

		void simultaneousAccepts(bool v) {
			if (!isOpen) return;
			libuv.uv_tcp_simultaneous_accepts(&ctx_tcp, v ? 1 : 0);
		}

		bool isOpen() { return !hasBeenClosed; }
	}

	static managed!ISocket_TCPServer create(Address address, ushort listBacklogAmount=64, IAllocator alloc=theAllocator()) {
		if (address is null || alloc is null) return managed!ISocket_TCPServer.init;
		auto ret = alloc.make!LibUVTCPServer(listBacklogAmount, alloc);

		if (address.addressFamily == AddressFamily.INET) {
			(*cast(sockaddr_in*)&ret.addrstorage) = *cast(sockaddr_in*)address.name();
		} else if (address.addressFamily == AddressFamily.INET6) {
			(*cast(sockaddr_in6*)&ret.addrstorage) = *cast(sockaddr_in6*)address.name();
		} else assert(0, "Unknown address format");

		if (libuv.uv_tcp_bind(&ret.ctx_tcp, cast(sockaddr*)&ret.addrstorage, 0) != 0) {
			alloc.dispose(ret);
			return managed!ISocket_TCPServer.init;
		}

		if (libuv.uv_listen(&ret.ctx_stream, ret.listBacklogAmount_, &onStreamServerConnectCB) != 0) {
			alloc.dispose(ret);
			return managed!ISocket_TCPServer.init;
		}

		ret.addToLifeLL();
		return cast(managed!ISocket_TCPServer)managed!LibUVTCPServer(ret, managers(), alloc);
	}

	void close()  {
		if (!isOpen) return;
		libuv.uv_close(&ctx_handle, &onStreamServerCloseCB);
	}
}

import std.stdio;

extern(C) {
	void onStreamServerConnectCB(uv_stream_t* server, int status) {
		if (status < 0) return;
		if (server.data is null) return;

		LibUVTCPServer serverSelf = *cast(LibUVTCPServer*)server.data;
		LibUVTCPSocket endpoint = serverSelf.alloc.make!LibUVTCPSocket(serverSelf, serverSelf.alloc);

		if (libuv.uv_accept(server, &endpoint.ctx_stream) == 0) {
			endpoint.startAccept();

			if (endpoint.isOpen) {
				endpoint.addToLifeLL();
				if (serverSelf.onStreamServerConnectedDel !is null)
					serverSelf.onStreamServerConnectedDel(serverSelf, endpoint);
			} else {
				serverSelf.alloc.dispose(endpoint);
			}
		} else {
			serverSelf.alloc.dispose(endpoint);
		}
	}

	void onStreamServerCloseCB(uv_handle_t* handle) {
		if (handle.data is null) return;
		LibUVTCPServer self = *cast(LibUVTCPServer*)handle.data;

		if (self.hasBeenClosed) return;
		self.hasBeenClosed = true;

		if (self.onStreamCloseDel !is null) self.onStreamCloseDel(self);
	}
}
