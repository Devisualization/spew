module cf.spew.event_loop.defs;
import cf.spew.events.defs : EventSource, Event;
import std.experimental.allocator : IAllocator;
import core.time : Duration;

interface IEventLoopThing {
	@property {
		bool onMainThread();
		bool onAdditionalThreads();
	}
}

interface EventLoopSource : IEventLoopThing {
	@property {
		EventSource identifier();
	}

	EventLoopSourceRetriever nextEventGenerator(IAllocator);
}

interface EventLoopConsumer : IEventLoopThing {
	import std.typecons : Nullable;
	
	@property {
		Nullable!EventSource pairOnlyWithSource();

		/// If you transform and not consume, make this negative, 0 to just "see" it and do nothing.
		byte priority();
	}

	/**
	 * Returns:
	 * 		If the event is consumed
	 */
	bool processEvent(ref Event event);
}

interface EventLoopSourceRetriever {
	/**
	 * Returns:
	 * 		If a valid event
	 */
	bool nextEvent(ref Event event);

	void handledEvent(ref Event event);
	void unhandledEvent(ref Event event);

	void hintTimeout(Duration timeout);
}
















enum ThreadState : ubyte {
	Unknown,

	Uninitialized,
	Started,
	Stopped,
	Initialized,
	Initializing
}

abstract class IEventLoopManager {
	public import core.time : Duration, seconds;
	public import core.thread : ThreadID, Thread;

	import std.experimental.containers.map;
	import std.experimental.allocator;
	import core.atomic : atomicLoad, atomicStore, atomicOp;
	import core.sync.mutex;

	protected {
		IAllocator allocator;
		ThreadID mainThreadID;

		Map!(ThreadID, ThreadState) threadsState = void;

		Mutex mutex_threadsStateAlter;
	}

	this(IAllocator allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) {
		this.allocator = allocator;
		this.mainThreadID = mainThreadID;
		this.threadsState = Map!(ThreadID, ThreadState)(allocator);

		this.mutex_threadsStateAlter = allocator.make!Mutex;
	}

	abstract {
		void addConsumers(EventLoopConsumer[]...);
		void addSources(EventLoopSource[]...);
		void clearConsumers();
		void clearSources();

		bool runningOnMainThread();
		bool runningOnAuxillaryThreads();
		uint countRunningOnAuxillaryThread();

		void stopMainThread();
		void stopAuxillaryThreads();
		void stopAllThreads();
		void stopCurrentThread();

		void setSourceTimeout(Duration duration = 0.seconds);
		void executeImpl(ThreadID threadId);
	}

	void execute() {
		ThreadID currentThread = Thread.getThis().id;

		// this code block must execute for this thread
		//  otherwise we won't have a proper state
		synchronized(mutex_threadsStateAlter) {
			bool found;
			foreach(k; threadsState.keys) {
				if (currentThread == k) {
					found = true;
					break;
				}
			}

			if (!found)
				threadsState[currentThread] = ThreadState.Uninitialized;
		}

		// cleans up up the thread state from previous dead threads
		// however it is not urgent as to when it should run
		cleanup();

		// ok now implementation code can execute as it is all nice and happy
		executeImpl(currentThread);
	}

	protected {
		pragma(inline, true)
		bool isMainThread(ThreadID id = Thread.getThis().id) { return id == mainThreadID; }

		pragma(inline, true)
		bool isThreadAlive(ThreadID id) {
			import core.thread : thread_findByAddr;
			return thread_findByAddr(id) !is null;
		}

		void cleanup() {
			// not urgent that we clean up, so don't worry about it
			if (mutex_threadsStateAlter.tryLock) {
				foreach(ThreadID k; threadsState.keys) {
					if (!isThreadAlive(k)) {
						threadsState.remove(k);
					}
				}

				mutex_threadsStateAlter.unlock;
			}
		}

	}
}