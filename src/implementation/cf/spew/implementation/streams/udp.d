/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.streams.udp;
import cf.spew.implementation.streams.base;
import cf.spew.streams.defs;
import cf.spew.streams.udp;
import devisualization.util.core.memory.managed;
import devisualization.bindings.libuv.uv;
import std.experimental.allocator : IAllocator, theAllocator, make, dispose, makeArray;
import std.socket : Address, InternetAddress, Internet6Address, AddressFamily;
import core.time : Duration;

abstract class AnUDPLocalPoint : StreamPoint, ISocket_UDPLocalPoint {

}

abstract class AnUDPEndPoint : StreamPoint, ISocket_UDPEndPoint {
}

class LibUVUDPLocalPoint : AnUDPLocalPoint {
	package(cf.spew.implementation) {
		union {
			uv_handle_t ctx_handle;
			uv_stream_t ctx_stream;
			uv_udp_t ctx_udp;
		}

		IAllocator alloc;
		bool hasBeenClosed;
		LibUVUDPLocalPoint self;
	}

	this(IAllocator alloc) {
		import cf.spew.event_loop.wells.libuv;

		this.alloc = alloc;
		uv_udp_init(getThreadLoop_UV(), &ctx_udp);

		self = this;
		ctx_udp.data = &self;
	}

	bool joinMulticastGroup(scope string multicastAddress, scope string interfaceAddress=null) {
		return handleMulticastGroup(multicastAddress, interfaceAddress, uv_membership.UV_JOIN_GROUP);
	}

	bool leaveMulticastGroup(scope string multicastAddress, scope string interfaceAddress=null) {
		return handleMulticastGroup(multicastAddress, interfaceAddress, uv_membership.UV_LEAVE_GROUP);
	}

	bool handleMulticastGroup(scope string multicastAddress, scope string interfaceAddress, uv_membership membership) {
		if (multicastAddress.length == 0) return false;

		char[] theCopyMulticast, theCopyInterface;
		string toSendMulticast = multicastAddress,
			toSendInterface = interfaceAddress;

		if (multicastAddress[$-1] != '\0') {
			theCopyMulticast = alloc.makeArray!char(multicastAddress.length+1);
			theCopyMulticast[0 .. $-1] = multicastAddress[];
			toSendMulticast = cast(string)theCopyMulticast;
		}

		if (interfaceAddress.length > 0) {
			if (interfaceAddress[$-1] != '\0') {
				theCopyInterface = alloc.makeArray!char(interfaceAddress.length+1);
				theCopyInterface[0 .. $-1] = interfaceAddress[];
				toSendInterface = cast(string)theCopyInterface;
			}
		}

		int ret = uv_udp_set_membership(&ctx_udp, cast(const(char)*)toSendMulticast.ptr, cast(const(char)*)toSendInterface.ptr, membership);

		if (theCopyMulticast.length > 0)
			alloc.dispose(theCopyMulticast);
		if (theCopyInterface.length > 0)
			alloc.dispose(theCopyInterface);

		return ret == 0;
	}

	@property {
		void multicastLoopBack(bool v) {
			if (!isOpen) return;
			uv_udp_set_multicast_loop(&ctx_udp, v ? 1 : 0);
		}

		bool multicastInterface(scope string input) {
			if (input.length == 0) return false;

			char[] theCopy;
			string toSend = input;

			if (input[$-1] != '\0') {
				theCopy = alloc.makeArray!char(input.length+1);
				theCopy[0 .. $-1] = input[];
				toSend = cast(string)theCopy;
			}

			int ret = uv_udp_set_multicast_interface(&ctx_udp, cast(const(char)*)toSend.ptr);

			if (theCopy.length > 0)
				alloc.dispose(theCopy);

			return ret == 0;
		}

		void multicastTTL(ubyte value=1) {
			if (!isOpen) return;
			
			if (value == 0) value = 1;
			uv_udp_set_multicast_ttl(&ctx_udp, value);
		}

		void broadcast(bool v) {
			if (!isOpen) return;
			uv_udp_set_broadcast(&ctx_udp, v ? 1 : 0);
		}

		void ttl(ubyte value=1) {
			if (!isOpen) return;

			if (value == 0) value = 1;
			uv_udp_set_ttl(&ctx_udp, value);
		}

		bool isOpen() { return !hasBeenClosed; }

		bool readable() {
			if (!isOpen) return false;
			else return uv_is_readable(&ctx_stream) == 1;
		}
	}

	~this() {
		if (isOpen) {
			ctx_udp.data = null;
			close();
		}
	}

	static managed!ISocket_UDPLocalPoint create(Address address, IAllocator alloc=theAllocator()) {
		if (address is null || alloc is null) return managed!ISocket_UDPLocalPoint.init;
		auto ret = alloc.make!LibUVUDPLocalPoint(alloc);

		sockaddr_storage addrstorage;

		if (address.addressFamily == AddressFamily.INET) {
			(*cast(sockaddr_in*)&addrstorage) = *cast(sockaddr_in*)address.name();
		} else if (address.addressFamily == AddressFamily.INET6) {
			(*cast(sockaddr_in6*)&addrstorage) = *cast(sockaddr_in6*)address.name();
		} else assert(0, "Unknown address format");

		if (uv_udp_bind(&ret.ctx_udp, cast(sockaddr*)&addrstorage, 0) != 0) {
			alloc.dispose(ret);
			return managed!ISocket_UDPLocalPoint.init;
		}

		if (uv_udp_recv_start(&ret.ctx_udp, &streamUDPAllocCB, &streamUDPReadCB) != 0) {
			alloc.dispose(ret);
			return managed!ISocket_UDPLocalPoint.init;
		}

		ret.addToLifeLL();
		return cast(managed!ISocket_UDPLocalPoint)managed!LibUVUDPLocalPoint(ret, managers(), alloc);
	}
	
	managed!Address localAddress(IAllocator alloc=theAllocator()) {
		sockaddr_storage addr;
		int alen = sockaddr_storage.sizeof;

		if (!isOpen || uv_udp_getsockname(&ctx_udp, cast(sockaddr*)&addr, &alen) != 0) {
		} else if (addr.ss_family == AF_INET) {
			return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addr), managers(), alloc);
		} else if (addr.ss_family == AF_INET6) {
			return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addr), managers(), alloc);
		}
		
		return managed!Address.init;
	}

	managed!ISocket_UDPEndPoint connectTo(Address address, IAllocator alloc=theAllocator()) {
		import std.typecons : tuple;

		if (address is null || alloc is null) return managed!ISocket_UDPEndPoint.init;
		sockaddr_storage addr_storage;

		if (address.addressFamily == AddressFamily.INET) {
			(*cast(sockaddr_in*)&addr_storage) = *cast(sockaddr_in*)address.name();
		} else if (address.addressFamily == AddressFamily.INET6) {
			(*cast(sockaddr_in6*)&addr_storage) = *cast(sockaddr_in6*)address.name();
		} else assert(0, "Unknown address format");

		return cast(managed!ISocket_UDPEndPoint)managed!LibUVUDPEndPoint(managers(), tuple(addr_storage, this, alloc), alloc);
	}

	void close()  {
		if (!isOpen) return;
		
		uv_read_stop(&ctx_stream);
		uv_close(&ctx_handle, &streamUDPCloseCB);
	}
}

class LibUVUDPEndPoint : AnUDPEndPoint {
	package(cf.spew.implementation) {
		LibUVUDPLocalPoint localPoint_;
		sockaddr_storage addrstorage;
		IAllocator alloc;
	}

	this(sockaddr_storage addr, LibUVUDPLocalPoint localPoint_, IAllocator alloc) {
		this.addrstorage = addr;
		this.localPoint_ = localPoint_;
		this.alloc = alloc;

		this.addToLifeLL();
	}

	@property {
		void blocking(bool v) {
			if (!isOpen) return;
			uv_stream_set_blocking(&localPoint_.ctx_stream, v ? 1 : 0);
		}

		bool writable() {
			if (!isOpen) return false;
			return uv_is_writable(&localPoint_.ctx_stream) == 1;
		}

		bool isOpen() { return localPoint_.isOpen; }
		ISocket_UDPLocalPoint localPoint() { return localPoint_; }
	}

	void write(const(ubyte[]) data...) {
		import core.memory : GC;

		LibUVWriteUDP* writebuf = alloc.make!LibUVWriteUDP;
		GC.removeRoot(writebuf);
		
		writebuf.req.data = writebuf;
		writebuf.alloc = alloc;
		
		char* buffer = alloc.makeArray!char(data.length).ptr;
		GC.removeRoot(buffer);
		
		buffer[0 .. data.length] = cast(char[])data[];
		
		assert(data.length < uint.max, "Too big of data to write, limit uint.max");
		writebuf.buf = uv_buf_init(buffer, cast(uint)data.length);
		uv_write(&writebuf.req, &localPoint_.ctx_stream, cast(const)&writebuf.buf, 1, &streamUDPWriteCB);
	}

	managed!Address remoteAddress(IAllocator alloc=theAllocator()) {
		if (!isOpen) {
		} else if (addrstorage.ss_family == AF_INET) {
			return cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(*cast(sockaddr_in*)&addrstorage), managers(), alloc);
		} else if (addrstorage.ss_family == AF_INET6) {
			return cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(*cast(sockaddr_in6*)&addrstorage), managers(), alloc);
		}
		
		return managed!Address.init;
	}

	void close() {}
}

private {
	struct LibUVWriteUDP {
		IAllocator alloc;
		uv_write_t req;
		uv_buf_t buf;
	}
}

extern(C) {
	void streamUDPWriteCB(uv_write_t* req, int status) {
		auto writebuf = cast(LibUVWriteUDP*)req.data;
		
		writebuf.alloc.dispose(cast(ubyte[])writebuf.buf.base[0 .. writebuf.buf.len]);
		writebuf.alloc.dispose(writebuf);
	}

	void streamUDPCloseCB(uv_handle_t* handle, int status) {
		if (handle.data is null) return;
		auto self = *cast(LibUVUDPLocalPoint*)handle.data;
		
		if (self.hasBeenClosed) return;
		self.hasBeenClosed = true;
		
		if (self.onStreamCloseDel !is null)
			self.onStreamCloseDel(self);
	}

	void streamUDPAllocCB(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
		import core.memory : GC;
		
		if (handle.data is null) return;
		auto self = *cast(LibUVUDPLocalPoint*)handle.data;
		
		buf.base = self.alloc.makeArray!char(suggested_size).ptr;
		GC.removeRoot(buf.base);
		buf.len = suggested_size;
	}

	void streamUDPReadCB(uv_udp_t* handle, ptrdiff_t nread, const(uv_buf_t)* buf, const(sockaddr)* addr, uint flags) {
		if (handle.data is null || addr is null) return;
		auto self = *cast(LibUVUDPLocalPoint*)handle.data;
		if (self is null) return;

		sockaddr_storage addr_storage;
		if (addr.sa_family == AF_INET) {
			(*cast(sockaddr_in*)&addr_storage) = *cast(sockaddr_in*)addr;
		} else if (addr.sa_family == AF_INET6) {
			(*cast(sockaddr_in6*)&addr_storage) = *cast(sockaddr_in6*)addr;
		}

		auto endpoint = self.alloc.make!LibUVUDPEndPoint(addr_storage, self, self.alloc);

		if (self.onDataDel !is null) {
			if (nread > 0 && self.onDataDel(endpoint, cast(ubyte[])buf.base[0 .. cast(size_t)nread])) {}
			else self.close();
		} else if (nread < 0) self.close();

		self.alloc.dispose(endpoint);
		self.alloc.dispose(cast(char[])buf.base[0 .. buf.len]);
	}
}