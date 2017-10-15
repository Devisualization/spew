///
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
		/// Streams implementation, might be only available on the main thread.
		shared(Management_Streams) streams() shared;

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
	import std.experimental.allocator : IAllocator, theAllocator;

	///
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared;
	
	///
	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	IWindow createAWindow(IAllocator alloc = theAllocator()) shared;
	
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
	import cf.spew.streams.defs;
	import std.socket : Address;
	import std.experimental.allocator : IAllocator, theAllocator;

	///
	managed!IStreamCreator createStream(StreamType type, IAllocator alloc=theAllocator()) shared;

	///
	managed!(Address[]) allLocalAddress(IAllocator alloc=theAllocator()) shared;

	/// 
	void forceCloseAll() shared;
}