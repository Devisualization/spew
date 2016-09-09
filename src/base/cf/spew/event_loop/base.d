module cf.spew.event_loop.base;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import std.experimental.allocator;
import core.thread : ThreadID, Thread;
import core.time : Duration, seconds;

/// Base implementation which you're not required to use, just makes things a little easier
abstract class EventLoopManager_Base : IEventLoopManager {
	import std.experimental.containers.map;
	import core.sync.mutex;
	
	protected {
		IAllocator allocator;
		ThreadID mainThreadID;
		void delegate(ThreadID, Exception) onErrorDelegate;
		
		Map!(ThreadID, ThreadState) threadsState = void;
		
		Mutex mutex_threadsStateAlter, mutex_threadsStateModify;
	}
	
	this(IAllocator allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) {
		this.allocator = allocator;
		this.mainThreadID = mainThreadID;
		this.threadsState = Map!(ThreadID, ThreadState)(allocator);
		
		this.mutex_threadsStateAlter = allocator.make!Mutex;
		this.mutex_threadsStateModify = allocator.make!Mutex;

		this.threadsState[mainThreadID] = ThreadState.Uninitialized;
	}
	
	bool runningOnThreadFor(ThreadID id = Thread.getThis().id) {
		synchronized(mutex_threadsStateModify) {
			return threadsState[id] == ThreadState.Started;
		}
	}
	
	void stopMainThread() {
		synchronized(mutex_threadsStateModify) {
			threadsState[mainThreadID] = ThreadState.Stop;
		}
	}
	
	void stopAuxillaryThreads() {
		synchronized(mutex_threadsStateModify) {
			foreach(id, ref state; threadsState) {
				if (id != mainThreadID && threadsState[id] == ThreadState.Started)
					state = ThreadState.Stop;
			}
		}
	}
	
	void stopAllThreads() {
		synchronized(mutex_threadsStateModify) {
			foreach(id, ref state; threadsState) {
				if (threadsState[id] == ThreadState.Started)
					state = ThreadState.Stop;
			}
		}
	}
	
	void stopThreadFor(ThreadID id = Thread.getThis().id) {
		synchronized(mutex_threadsStateModify) {
			if (threadsState[id] == ThreadState.Started)
				threadsState[id] = ThreadState.Stop;
		}
	}
	
	bool runningOnMainThread() {
		synchronized(mutex_threadsStateModify) {
			return threadsState[mainThreadID] == ThreadState.Started;
		}
	}
	
	bool runningOnAuxillaryThreads() {
		return countRunningOnAuxillaryThread > 0;
	}
	
	uint countRunningOnAuxillaryThread() {
		synchronized(mutex_threadsStateModify) {
			uint ret;
			foreach(id, ref state; threadsState) {
				if (state == ThreadState.Started)
					ret++;
			}
			return ret;
		}
	}
	
	void notifyOfThread(ThreadID id = Thread.getThis().id) {
		// this code block must execute for this thread
		//  otherwise we won't have a proper state
		synchronized(mutex_threadsStateAlter) {
			// prevents somebody else from adding/removing entries
			
			bool found;
			foreach(k; threadsState.keys) {
				if (id == k) {
					found = true;
					break;
				}
			}
			
			if (!found)
				threadsState[id] = ThreadState.Uninitialized;
		}
	}
	
	void registerOnErrorDelegate(void delegate(ThreadID, Exception) del) {
		onErrorDelegate = del;
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
		notifyOfThread(currentThread);
		
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
		
		void cleanupRemovingImpl(ThreadID);
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
							cleanupRemovingImpl(k);
							threadsState.remove(k);
						}
					}
				}
				
				mutex_threadsStateAlter.unlock;
			}
		}
		
	}
}