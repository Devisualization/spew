/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.streams.tcp;
import cf.spew.streams.defs;
import core.time : Duration;

/**
 * TCP socket connection
 */
interface ISocket_TCP : IStreamLocalPoint, IStreamEndPoint {
	@property {
		/// The TCP server, null for a client-only connection.
		ISocket_TCPServer server();

		/// Disables (when true) for TCP, Nagle`s algorithm. 
		void noDelay(bool);
		
		/**
		 * Enables keep alive on a TCP socket.
		 * 
		 * Params:
		 *     duration = How long a timeout should be. Zero will disable. Will round up depending upon the implementation.
		 */
		void keepAliveTimeout(Duration duration);
	}
}

/**
 * TCP socket server
 */
interface ISocket_TCPServer : IStreamServer {
	@property {
		/// Disables (when false) for TCP, simultaneous accepting of connections.
		void simultaneousAccepts(bool);
	}
}