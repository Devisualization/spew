/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.streams.udp;
import cf.spew.streams.defs;
import devisualization.util.core.memory.managed;
import std.experimental.allocator : IAllocator, theAllocator;
import std.socket : Address;
import core.time : Duration;

///
interface ISocket_UDPLocalPoint : IStreamLocalPoint {
	/// Joins a multicast group
	bool joinMulticastGroup(scope string multicastAddress, scope string interfaceAddress=null);

	/// Leaves a multicast group
	bool leaveMulticastGroup(scope string multicastAddress, scope string interfaceAddress=null);

	@property {
		/// Makes multicast packets loopback to local sockets
		void multicastLoopBack(bool);

		/// Address that multicasting should occur from
		bool multicastInterface(scope string);

		/// Sets the TTL on a multicast connection, 0 rounds up to 1.
		void multicastTTL(ubyte value=1);

		/// Turns on broadcasting
		void broadcast(bool);

		/// Sets the TTL, 0 rounds up to 1.
		void ttl(ubyte value=1);
	}

	/// Connects to a UDP end point
	managed!ISocket_UDPEndPoint connectTo(Address address, IAllocator alloc=theAllocator());
}

///
interface ISocket_UDPEndPoint : IStreamEndPoint {
	@property {
		/// The local end of this socket
		ISocket_UDPLocalPoint localPoint();
	}
}