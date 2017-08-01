///
module cf.spew.instance;

///
abstract class Instance {
	///
	@property {
		/// The event loop for this application
		shared(Management_EventLoop) eventLoop() shared;
		/// The user interfacing implementation for this application
		shared(Management_UserInterface) userInterface() shared;
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
	import std.experimental.memory.managed;

	///
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	IRenderPoint createARenderPoint(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
	
	///
	managed!IWindowCreator createWindow(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
	
	/// completely up to platform implementation to what the defaults are
	IWindow createAWindow(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
	
	@property {
		///
		managed!IDisplay primaryDisplay(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
		
		///
		managed!(IDisplay[]) displays(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
		
		///
		managed!(IWindow[]) windows(IAllocator alloc = cast(IAllocator)theAllocator()) shared;
	}
}