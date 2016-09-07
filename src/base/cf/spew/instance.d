module cf.spew.instance;

///
abstract class Instance {
	///
	@property {
		/// The event loop for this application
		Management_EventLoop eventLoop();
		/// The user interfacing implementation for this application
		Management_UserInterface userInterface();
		alias ui = userInterface;
	}

	///
	final nothrow @nogc @trusted {
		///
		void setAsTheImplementation() { theInstance_ = this; }

		///
		static {
			/// Default instance implementation, can be null
			Instance theDefault() { return defaultInstance_; }

			/// If null, no implementation has been configured
			/// Are you compiling in spew:implementation?
			Instance current() { return theInstance_; }
		}
	}
}

private __gshared {
	Instance defaultInstance_;
	Instance theInstance_;

	shared static this() {
		version(Have_spew_implementation) {
			import cf.spew.implementation.instance;
			pragma(msg, "spew:implementation is being used with a default implementation for S.P.E.W.");

			defaultInstance_ = new DefaultImplementation;
			theInstance_ = defaultInstance_;
		}
	}
}

/// Provides a general usage event loop manager overview
interface Management_EventLoop {
	import cf.spew.event_loop.defs : IEventLoopManager;

	/// Does the main thread have an event loop executing?
	bool isRunningOnMainThread();
	
	/// Does any of the threads have an event loop executing?
	bool isRunning();

	/// Stop the event loop for the current thread
	void stopCurrentThread();

	/// Stop the event loop on all threads
	void stopAllThreads();

	/// Starts the execution of the event loop for the current thread
	void execute();

	/// If you really want to get dirty, here it is!
	@property IEventLoopManager manager();
}

///
interface Management_UserInterface {
	import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
	import std.experimental.allocator : IAllocator, processAllocator;
	import std.experimental.memory.managed;

	///
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = processAllocator());
	
	/// completely up to platform implementation to what the defaults are
	IRenderPoint createARenderPoint(IAllocator alloc = processAllocator());
	
	///
	managed!IWindowCreator createWindow(IAllocator alloc = processAllocator());
	
	/// completely up to platform implementation to what the defaults are
	IWindow createAWindow(IAllocator alloc = processAllocator());
	
	@property {
		///
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator());
		
		///
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator());
		
		///
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator());
	}
}