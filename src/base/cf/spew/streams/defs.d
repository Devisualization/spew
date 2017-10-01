///
module cf.spew.streams.defs;
import std.experimental.memory.managed;
import std.experimental.allocator : IAllocator, theAllocator;
import std.socket : Address;
import core.time : Duration;

/**
 * Callback which is called when data is made available.
 * 
 * Params:
 *     data =  The data
 * 
 * Returns:
 *     To continue reading, or stop (false).
 */
alias OnStreamDataDel = bool delegate(IStreamEndpoint conn, const(ubyte[]) data);

/**
 * Callback which is called when stream is created/closed.
 * 
 * Params:
 *     conn =  The connection to the stream end point
 */
alias OnStreamLifeDel = void delegate(IStreamEndpoint conn);

/**
 * Callback which is called when stream server is closed.
 * 
 * Params:
 *     conn =  The connection to the stream server
 */
alias OnServerLifeDel = void delegate(IStreamServer server);
///
enum StreamType {
	///
	Error,
	///
	TCP,
	///
	UDP,
}

///
interface IStreamCreator {
	/// Disables (when true) for TCP, Nagle`s algorithm. 
	void tcp_nodelay(bool);

	/**
	 * Enables keep alive on a TCP socket.
	 * 
	 * Params:
	 *     duration = How long a timeout should be. Zero for disabled. Will round up depending upon the implementation.
	 */
	void tcp_keepAliveTimeout(Duration duration);

	@property {
		/**
		 * When a stream is created, call the callback
		 * 
		 * Params:
		 *     callback = Calls when a new client has connected.
		 */
		void onStreamCreate(OnStreamLifeDel callback);

		/**
		 * When the stream is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream closes.
		 */
		void onStreamClose(OnStreamLifeDel callback);

		/**
		 * When data is made available, call the callback
		 * 
		 * Params:
		 *     callback = Calls when the data was available.
		 */
		void onData(OnStreamDataDel callback);

		/**
		 * When the stream server is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream server closes.
		 */
		void onServerClose(OnServerLifeDel callback);

		/**
		 * Number of packets/connections to backlog for a server.
		 * 
		 * If you are unsure, do NOT set this!
		 */
		void listenBacklog(ushort amount);
	}

	/// Connects and constructs a stream end point.
	managed!IStreamEndpoint connectClient(scope Address);
	/// Listens and constructs a stream server.
	managed!IStreamServer bindServer(scope Address);
}

///
interface IStreamServer {
	@property {
		/**
		 * When a stream is created, call the callback
		 * 
		 * Params:
		 *     callback = Calls when a new client has connected.
		 */
		void onStreamCreate(OnStreamLifeDel callback);

		/**
		 * When the stream is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream closes.
		 */
		void onStreamClose(OnStreamLifeDel callback);

		/**
		 * When data is made available, call the callback (default)
		 * 
		 * Params:
		 *     callback = Calls when the data was available.
		 */
		void onData(OnStreamDataDel callback);

		/**
		 * When the stream server is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream server closes.
		 */
		void onServerClose(OnServerLifeDel callback);
	}

	/// Is the stream open still?
	bool isOpen();

	/// Closes the stream.
	void close();
}

/**
 * 
 * 
 * If created from a UDP server, do not keep a reference to an instance.
 * 
 */
interface IStreamEndpoint {
	/**
	 * Writes data to the stream.
	 * 
	 * Params:
	 *     data = The data to write
	 */
	void write(const(ubyte[]) data...);

	@property {
		/**
		 * When data is made available, call the callback
		 * 
		 * Params:
		 *     callback = Calls when the data was available.
		 */
		void onData(OnStreamDataDel callback);

		/**
		 * When the stream is closed, call the callback.
		 * 
		 * Params:
		 *     callback = Calls when the stream closes.
		 */
		void onStreamClose(OnStreamLifeDel callback);

		///
		StreamType type();
		/// If is a socket to a client, returns the server.
		IStreamServer server();

		/// Is the stream readable?
		bool readable();
		/// Is the stream writable?
		bool writable();
	}

	/// Gets the local address of the stream.
	managed!Address localAddress(IAllocator alloc=theAllocator());

	/// Gets the remote address of the stream.
	managed!Address remoteAddress(IAllocator alloc=theAllocator());

	/// Is the stream open still?
	bool isOpen();

	/// Closes the stream.
	void close();
}