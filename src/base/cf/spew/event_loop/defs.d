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
	/// /error/ /error/ /error/
	Unknown,

	/// not running and not initialized
	Uninitialized,

	/// running
	Started,

	/// is initialized but not running
	Stopped
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

		Mutex mutex_threadsStateAlter, mutex_threadsStateModify;
	}

	this(IAllocator allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) {
		this.allocator = allocator;
		this.mainThreadID = mainThreadID;
		this.threadsState = Map!(ThreadID, ThreadState)(allocator);

		this.mutex_threadsStateAlter = allocator.make!Mutex;
		this.mutex_threadsStateModify = allocator.make!Mutex;
	}

	abstract {
		/**
		 * Adds the provided consumers to the list.
		 * 
		 * If a consumer is already stored, it will be ignored.
		 */
		void addConsumers(EventLoopConsumer[]...);

		/**
		 * Adds the provided sources to the list.
		 * 
		 * If a source is already stored, it will be ignored.
		 */
		void addSources(EventLoopSource[]...);

		/// Removes all consumers from the list.
		void clearConsumers();

		/// Removes all the sources from the list.
		void clearSources();

		/// Does the main thread have an event loop executing?
		bool runningOnMainThread();

		/// Does any of the auxillary threads have an event loop executing?
		bool runningOnAuxillaryThreads();

		/// How many of the auxillary threads have an event loop executing? 
		uint countRunningOnAuxillaryThread();

		/// Is the event loop running on the current thread?
		bool runningOnCurrentThread();

		/// Stop the event loop only on the main thread
		void stopMainThread();

		/// Stop the event loop only on auxillary threads
		void stopAuxillaryThreads();

		/// Stop the event loop on all threads
		void stopAllThreads();

		/// Stop the event loop on the current thread
		void stopCurrentThread();

		/// For each source, set the timeout hint
		void setSourceTimeout(Duration duration = 0.seconds);

		/// Notifies that this thread should be "registered"
		void notifyOfThread(ThreadID id = Thread.getThis().id);
	}

	/**
	 * Starts the event loop for the current thread.
	 * 
	 * Will stop when the state of the thread is set to stopped.
	 * 
	 * Implementation:
	 * 		1. If the thread is not already stored, it is stored and set to uninitialized
	 *		2. If possible remove all non-existant threads
	 * 		3. If state has changed (per thread)
	 *			- If no event loops are executing
	 *				- Initialize the internal workings for all known (and hence "alive") threads
	 *			- else
	 *				- Initialize the internal workings for current thread
	 *		4. Use the internals for the current thread to execute the current event loop
	 */
	void execute() {
		if (runningOnCurrentThread) {
			// UMM WHAT! /error/ /error/ /error/
			return;
		}

		ThreadID currentThread = Thread.getThis().id;

		// this code block must execute for this thread
		//  otherwise we won't have a proper state
		synchronized(mutex_threadsStateAlter) {
			// prevents somebody else from adding/removing entries

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

		void* execute_ctx;
		synchronized(mutex_threadsStateModify) {
			// prevents somebody else from removing/modifying the entries

			if (runningOnAuxillaryThreads || runningOnMainThread) {
				execute_ctx = initializeImpl(currentThread);

				// Not running but it has been initialized
				threadsState[currentThread] = ThreadState.Stopped;
			} else {
				foreach(id, ref state; threadsState) {
					void* ctx = initializeImpl(id);

					if (id == currentThread)
						execute_ctx = ctx;

					// Not running but it has been initialized
					state = ThreadState.Stopped;
				}
			}

			threadsState[currentThread] = ThreadState.Started;
		}

		// ok now implementation code can execute as it is all nice and happy

		executeImpl(currentThread, execute_ctx);

		synchronized(mutex_threadsStateModify) {
			threadsState[currentThread] = ThreadState.Stopped;
		}
	}

	abstract protected {
		void* initializeImpl(ThreadID threadId);

		/// params are the current thread id and the context returned by initializeImpl
		void executeImpl(ThreadID threadId, void* ctx);
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
			// prevents somebody else from adding/removing entries
			if (mutex_threadsStateAlter.tryLock) {
				// don't let somebody else go modify existing entries while we are removing
				synchronized(mutex_threadsStateModify) {
					foreach(ThreadID k; threadsState.keys) {
						if (!isThreadAlive(k)) {
							threadsState.remove(k);
						}
					}
				}

				mutex_threadsStateAlter.unlock;
			}
		}

	}
}