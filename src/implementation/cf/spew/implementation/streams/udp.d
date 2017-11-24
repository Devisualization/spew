module cf.spew.implementation.streams.udp;
import cf.spew.implementation.streams.base;
import cf.spew.streams.defs;
import cf.spew.streams.udp;
import devisualization.util.core.memory.managed;
import std.experimental.allocator : IAllocator, theAllocator;
import std.socket : Address;
import core.time : Duration;

abstract class AnUDPLocalPoint : StreamPoint, ISocket_UDPLocalPoint {

}

abstract class AnUDPEndPoint : StreamPoint, ISocket_UDPEndPoint {
	private ISocket_UDPLocalPoint localPoint_;

	@property {
		ISocket_UDPLocalPoint localPoint() { return localPoint_; }
	}
}

class LibUVUDPLocalPoint : AnUDPLocalPoint {
	void joinMulticastGroup(scope Address multicastAddress, scope string interfaceAddress=null) { assert(0); }
	void leaveMulticastGroup(scope Address multicastAddress, scope string interfaceAddress=null) { assert(0); }
	
	@property {
		void multicastLoopBack(bool) { assert(0); }
		void multicastInterface(scope string) { assert(0); }
		void multicastTTL(ubyte value=1) { assert(0); }
		void broadcast(bool) { assert(0); }
		void ttl(ubyte value=1) { assert(0); }
		bool isOpen() { assert(0); }
		bool readable() { assert(0); }
	}

	static managed!ISocket_UDPLocalPoint create(Address address, IAllocator alloc=theAllocator()) {
		return managed!ISocket_UDPLocalPoint.init;
	}
	
	managed!Address localAddress(IAllocator alloc=theAllocator()) { assert(0); }
	managed!ISocket_UDPEndPoint connectTo(Address address, IAllocator alloc=theAllocator()) { assert(0); }
	void close()  { assert(0); }
}

class LibUVUDPEndPoint : AnUDPEndPoint {
	@property {
		void blocking(bool v) { assert(0); }
		bool writable() { assert(0); }
		bool isOpen() { assert(0); }
	}

	void write(const(ubyte[]) data...) { assert(0); }
	managed!Address remoteAddress(IAllocator alloc=theAllocator()) { assert(0); }
	void close()  { assert(0); }
}