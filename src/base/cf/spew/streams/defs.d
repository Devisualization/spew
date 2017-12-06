/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.streams.defs;
import devisualization.util.core.memory.managed;
import std.experimental.allocator : IAllocator, theAllocator;
import std.socket : Address;

/**
 * General stream lifetime management.
 */
interface IStreamThing {
	@property {
		/**
		 * When the stream is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream closes.
		 */
		void onStreamClose(OnStreamClosedDel callback);

		/// Is the stream open still?
		bool isOpen();
	}
	
	/// Closes the stream.
	void close();
}

/**
 * Local to our computer end to a stream.
 */
interface IStreamLocalPoint : IStreamThing {
	@property {
		/**
		 * When data is made available, call the callback
		 * 
		 * Params:
		 *     callback = Calls when the data was available.
		 */
		void onData(OnStreamDataDel callback);

		/// Is the stream readable?
		bool readable();
	}


	/// Gets the local address of the stream.
	managed!Address localAddress(IAllocator alloc=theAllocator());
}

/**
 * Remote to our computer end of the stream.
 */
interface IStreamEndPoint : IStreamThing {
	/**
	 * Writes data to the stream.
	 * 
	 * Params:
	 *     data = The data to write
	 */
	void write(const(ubyte[]) data...);
	
	@property {
		/**
		 * When the stream connects to an end point, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the server connects.
		 */
		void onConnect(OnStreamConnectedDel callback);

		/// Will write synchronously instead of asynchronously.
		void blocking(bool);

		/// Is the stream writable?
		bool writable();
	}

	/// Gets the remote address of the stream.
	managed!Address remoteAddress(IAllocator alloc=theAllocator());
}

///
interface IStreamServer : IStreamThing {
	@property {
		/**
		 * When the server connects to an end point, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the server connects.
		 */
		void onServerConnect(OnStreamServerConnectedDel callback);
	}
}

/**
 * Callback which is called when data is made available.
 * 
 * Params:
 *     conn = The local end point
 *     data =  The data
 * 
 * Returns:
 *     To continue reading, or stop (false).
 */
alias OnStreamDataDel = bool delegate(scope IStreamEndPoint conn, scope const(ubyte[]) data);

/**
 * Callback which is called when stream is closed.
 * 
 * Params:
 *     conn =  The connection to the stream end point
 */
alias OnStreamClosedDel = void delegate(scope IStreamThing conn);

/**
 * Callback which is called when server connects to a remote end point.
 * 
 * Params:
 *     server =  The server
 *     conn = The remote end point
 */
alias OnStreamServerConnectedDel = void delegate(scope IStreamServer server, scope IStreamEndPoint conn);

/**
 * Callback which is called when endpoint connects to a remote end point.
 * 
 * Params:
 *     conn = The remote end point
 */
alias OnStreamConnectedDel = void delegate(scope IStreamEndPoint conn);
