/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.instance;
import devisualization.util.core.memory.managed;

///
abstract class Instance {
	///
	@property {
		/// The event loop for this application
		shared(Management_EventLoop) eventLoop() shared;
		/// The user interfacing implementation for this application
		shared(Management_UserInterface) userInterface() shared;
		/// Streams implementation aka sockets.
		shared(Management_Streams) streams() shared;
		/// Got a better name for this?
		shared(Management_Miscellaneous) misc() shared;
		///
		pragma(inline, true)
		final shared(Management_UserInterface) ui() shared { return userInterface; }
	}

	///
	final nothrow @nogc @trusted {
		///
		void setAsTheImplementation() shared { theInstance_ = this; }

		///
		static {
			/// Default instance implementation, can be null
			shared(Instance) theDefault() { return defaultInstance_; }

			/// If null, no implementation has been configured
			/// Are you compiling in spew:implementation?
			shared(Instance) current() { return theInstance_; }
		}
	}
}

private __gshared {
	shared(Instance) defaultInstance_;
	shared(Instance) theInstance_;

	shared static this() {
		version(Have_spew_implementation) {
			import cf.spew.implementation.instance;
			pragma(msg, "spew:implementation is being used with a default implementation for S.P.E.W.");

			defaultInstance_ = new shared DefaultImplementation;
			theInstance_ = defaultInstance_;
		}
	}
}

/// Provides a general usage event loop manager overview
interface Management_EventLoop {
	import cf.spew.event_loop.defs : IEventLoopManager;

	/// Does the main thread have an event loop executing?
	bool isRunningOnMainThread() shared;
	
	/// Does any of the threads have an event loop executing?
	bool isRunning() shared;

	/// Stop the event loop for the current thread
	void stopCurrentThread() shared;

	/// Stop the event loop on all threads
	void stopAllThreads() shared;

	/// Starts the execution of the event loop for the current thread
	void execute() shared;

	/// If you really want to get dirty, here it is!
	@property shared(IEventLoopManager) manager() shared;
}

///
interface Management_UserInterface {
	import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
	import stdx.allocator : IAllocator, theAllocator;

	///
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	managed!IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared;
	
	///
	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	managed!IWindow createAWindow(IAllocator alloc = theAllocator()) shared;
	
	@property {
		///
		managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared;
		
		///
		managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared;
		
		///
		managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared;
	}
}

/// Beware, thread-local!
interface Management_Streams {
	import cf.spew.streams;
	import std.socket : Address;
	import stdx.allocator : IAllocator, theAllocator;

	/// A TCP server
	managed!ISocket_TCPServer tcpServer(Address address, ushort listBacklogAmount=64, IAllocator alloc=theAllocator()) shared;
	/// A TCP client
	managed!ISocket_TCP tcpConnect(Address address, IAllocator alloc=theAllocator()) shared;
	/// A UDP local end point, create destination from this
	managed!ISocket_UDPLocalPoint udpLocalPoint(Address address, IAllocator alloc=theAllocator()) shared;

	///
	managed!(managed!Address[]) allLocalAddress(IAllocator alloc=theAllocator()) shared;

	/// 
	void forceCloseAll() shared;
}

/// Beware, thread-local!
interface Management_Miscellaneous {
	import stdx.allocator : IAllocator, theAllocator;
	import cf.spew.miscellaneous;
	import core.time : Duration;

	/**
	 * Creates a timer.
	 * 
	 * Params:
	 *     timeout = Timeout till callback is called.
	 *     hintSystemWait = If possible an event loop able thread stopper implementation will be used,
	 *                                Otherwise a constantly checking one (costly) will be used.
	 * 
	 * Returns:
	 *     A timer
	 */
	managed!ITimer createTimer(Duration timeout, bool hintSystemWait=true, IAllocator alloc=theAllocator()) shared;

	/// Watches a directory recursively (if possible) and notifies of changes.
	managed!IFileSystemWatcher createFileSystemWatcher(string path, IAllocator alloc=theAllocator()) shared;
}