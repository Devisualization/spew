module cf.spew.implementation.instance;
import cf.spew.instance;
import std.experimental.allocator : IAllocator, make, dispose, processAllocator;

final class DefaultImplementation : Instance {
	import cf.spew.event_loop.defs : EventLoopSource, EventLoopConsumer;

	~this() {
		if (__Initialized) {
			allocator.dispose(_eventLoop);
			allocator.dispose(_userInterface);

			allocator.dispose(_mainEventSource_);
			allocator.dispose(_mainEventConsumer_);

		}
	}

	bool __Initialized;
	IAllocator allocator;
	Management_EventLoop _eventLoop;
	Management_UserInterface _userInterface;

	@property {
		override Management_EventLoop eventLoop() {
			__guardCheck();
			return _eventLoop;
		}

		override Management_UserInterface userInterface() {
			__guardCheck();
			return _userInterface;
		}
	}

	// this can be safely inlined!
	pragma(inline, true)
	void __guardCheck() {
		if (!__Initialized)
			__handleGuardCheck();
	}

	private {
		EventLoopSource _mainEventSource_;
		EventLoopConsumer _mainEventConsumer_;
	}

	void __handleGuardCheck() {
		__Initialized = true;
		allocator = processAllocator;

		_eventLoop = allocator.make!EventLoopWrapper(allocator);

		version(Windows) {
			import cf.spew.event_loop.wells.winapi;
			import cf.spew.implementation.consumers;

			_mainEventSource_ = allocator.make!WinAPI_EventLoop_Source;
			_eventLoop.manager.addSources(_mainEventSource_);
			//_mainEventConsumer_ = allocator.make!EventLoopConsumerImpl_WinAPI(this);
			_eventLoop.manager.addConsumers(_mainEventConsumer_);
		}
	}
}

final class EventLoopWrapper : Management_EventLoop {
	import cf.spew.event_loop.defs : IEventLoopManager;
	import cf.spew.implementation.manager;

	this(IAllocator allocator) {
		this.allocator = allocator;
		_manager = allocator.make!EventLoopManager_Impl;
	}

	~this() {
		allocator.dispose(_manager);
	}

	IAllocator allocator;
	IEventLoopManager _manager;

	bool isRunningOnMainThread() { return _manager.runningOnMainThread; }
	bool isRunning() { return _manager.runningOnMainThread || _manager.runningOnAuxillaryThreads; }
	void stopCurrentThread() { _manager.runningOnThreadFor; }
	void stopAllThreads() { _manager.stopAllThreads; }
	void execute() { _manager.execute; }

	@property IEventLoopManager manager() { return _manager; }
}

