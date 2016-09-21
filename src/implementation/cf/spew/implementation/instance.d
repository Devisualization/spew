module cf.spew.implementation.instance;
import cf.spew.instance;
import std.experimental.allocator : IAllocator, make, dispose, processAllocator;
import std.experimental.memory.managed;
import cf.spew.ui.rendering : vec2;

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
			_mainEventConsumer_ = allocator.make!EventLoopConsumerImpl_WinAPI(this);
			_eventLoop.manager.addConsumers(_mainEventConsumer_);
			_userInterface = allocator.make!UIInstance_WinAPI(allocator);
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

abstract class UIInstance : Management_UserInterface {
	import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
	import std.experimental.allocator : IAllocator, processAllocator;
	import std.experimental.memory.managed;

	this(IAllocator allocator) {
		this.allocator = allocator;
	}

	IAllocator allocator;

	managed!IWindowCreator createWindow(IAllocator alloc = processAllocator()) { assert(0); }

	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = processAllocator())
	{ return cast(managed!IRenderPointCreator)createWindow(alloc); }

	IRenderPoint createARenderPoint(IAllocator alloc = processAllocator())
	{ return createAWindow(alloc); }

	IWindow createAWindow(IAllocator alloc = processAllocator()) {
		import cf.spew.ui.context.features.vram;

		auto creator = createWindow(alloc);
		creator.size = vec2!ushort(cast(short)800, cast(short)600);
		creator.assignVRamContext;
		return creator.createWindow();
	}
	
	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator()) { assert(0); }
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator()) { assert(0); }
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator()) { assert(0); }
	}
}

version(Windows) {
	final class UIInstance_WinAPI : UIInstance {
		import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_WinAPI;
		import std.typecons : tuple;

		this(IAllocator allocator) {
			super(allocator);
		}

		override {
			managed!IWindowCreator createWindow(IAllocator alloc = processAllocator()) {
				return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(), tuple(this, alloc), alloc);
			}

			@property {
				managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator()) { assert(0); }
				managed!(IDisplay[]) displays(IAllocator alloc = processAllocator()) { assert(0); }
				managed!(IWindow[]) windows(IAllocator alloc = processAllocator()) { assert(0); }
			}
		}
	}
}