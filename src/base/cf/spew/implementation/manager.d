module cf.spew.implementation.manager;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;
import std.experimental.allocator;
import core.thread : ThreadID, Thread;
import core.time : Duration, seconds;

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

class EventLoopManager_Impl : EventLoopManager_Base {
	import std.experimental.containers.list;
	import std.experimental.containers.map;
	import core.atomic : atomicLoad, atomicStore, atomicOp;
	import core.sync.mutex;

	protected {
		Duration hintSourceTimeout;

		Mutex mutex_sourcesAlter, mutex_consumersAlter;
		List!EventLoopSource sources = void;
		List!EventLoopConsumer consumers = void;

		Mutex mutex_threadData;
		Map!(ThreadID, InternalData) threadData;
	}

	this(IAllocator allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) {
		super(allocator, mainThreadID);

		this.hintSourceTimeout = 0.seconds;
		this.onErrorDelegate = &onErrorDelegateDefaultImpl;

		this.sources = List!EventLoopSource(allocator);
		this.consumers = List!EventLoopConsumer(allocator);

		this.mutex_sourcesAlter = allocator.make!Mutex;
		this.mutex_consumersAlter = allocator.make!Mutex;
		this.mutex_threadData = allocator.make!Mutex;
	}

	void addConsumers(EventLoopConsumer[] toAdd...) {
		synchronized(mutex_consumersAlter) {
			foreach(v; toAdd) {
				bool dontAdd;
				foreach(csmr; consumers) {
					if (csmr == v) {
						dontAdd = true;
					}
				}

				if (!dontAdd)
					consumers ~= v;
			}
		}
	}

	void addSources(EventLoopSource[] toAdd...) {
		synchronized(mutex_sourcesAlter) {
			foreach(v; toAdd) {
				bool dontAdd;
				EventSource id = v.identifier;

				foreach(src; sources) {
					if (src == v || src.identifier == id) {
						dontAdd = true;
					}
				}
				
				if (!dontAdd)
					sources ~= v;
			}
		}
	}

	void clearConsumers() {
		synchronized(mutex_consumersAlter) {
			consumers.length = 0;
		}
	}

	void clearSources() {
		synchronized(mutex_sourcesAlter) {
			sources.length = 0;
		}
	}

	void setSourceTimeout(Duration duration = 0.seconds) {
		this.hintSourceTimeout = duration;
	}

	string describeRules();
	string describeRulesFor(ThreadID id = Thread.getThis().id);

	protected {
		void onErrorDelegateDefaultImpl(ThreadID, Exception) {}
	}

	protected override {
		void cleanupRemovingImpl(ThreadID id) {
			synchronized(mutex_threadData) {
				atomicOp!"-="(threadData[id].refCount, 1);
				if (atomicLoad(threadData[id].refCount) == 0)
					threadData.remove(id);
				threadsState.remove(id);
			}
		}

		void* initializeImpl(ThreadID threadId) {
			InternalData ret = allocator.make!InternalData;
			ret.refCount = 1;

			bool isOnMainThread = isMainThread(threadId);

			EventLoopConsumer[] allConsumers = allocator.makeArray!EventLoopConsumer(consumers.length);
			EventLoopSource[] allSources = allocator.makeArray!EventLoopSource(sources.length);
			EventLoopConsumer[] allConsumersSlice;
			EventLoopSource[] allSourcesSlice;

			size_t i;
			foreach(consumer; consumers) {
				if ((isOnMainThread && consumer.onMainThread) || (!isOnMainThread && consumer.onAdditionalThreads)) {
					allConsumers[i] = consumer;
					i++;
				}
			}
			allConsumersSlice = allConsumers[0 .. i];

			i = 0;
			foreach(source; sources) {
				if ((isOnMainThread && source.onMainThread) || (!isOnMainThread && source.onAdditionalThreads)) {
					allSources[i] = source;
					i++;
				}
			}
			allSourcesSlice = allSourcesSlice[0 .. i];
			ret.instances = allocator.makeArray!(InternalData.Instance)(allSourcesSlice.length);

			i = 0;
			foreach(source; allSourcesSlice) {
				short lastPriority = byte.min;
				size_t countAddedSoFar;

				ret.instances[i].retriever = source.nextEventGenerator(allocator);
				ret.instances[i].retriever.hintTimeout(hintSourceTimeout);

				ret.instances[i].consumers = allocator.makeArray!EventLoopConsumer(allConsumersSlice.length);

				while (countAddedSoFar < allSourcesSlice.length) {
					foreach(consumer; allConsumersSlice) {
						if (consumer.pairOnlyWithSource.isNull || consumer.pairOnlyWithSource.get == source.identifier) {
							if (consumer.priority == lastPriority) {
								ret.instances[i].consumers[countAddedSoFar] = consumer;
								countAddedSoFar++;
							}
						}
					}

					lastPriority++;
				}

				i++;
			}

			allocator.dispose(allConsumers);
			allocator.dispose(allSources);

			synchronized(mutex_threadData) {
				threadData[threadId] = ret;
				return cast(void*)ret;
			}
		}

		void executeImpl(ThreadID threadId, void* ctx) {
			InternalData data = cast(InternalData)ctx;
			atomicOp!"+="(data.refCount, 1);

			while(threadsState[threadId] != ThreadState.Stop) {
				foreach(instance; data.instances) {
					Event event;
					while(instance.retriever.nextEvent(event)) {
						bool handled;

						try {
							foreach(consumer; instance.consumers) {
								if (event.type == consumer.pairOnlyWithEvents) {
									handled = true;
									consumer.processEvent(event);
								}
							}

							if (handled)
								instance.retriever.handledEvent(event);
							else
								instance.retriever.unhandledEvent(event);
						} catch(Exception e) {
							instance.retriever.handledErrorEvent(event);
							onErrorDelegate(threadId, e);
						}
					}
				}
			}

			atomicOp!"-="(data.refCount, 1);
			if (atomicLoad(data.refCount) == 0)
				allocator.dispose(data);
		}
	}

	final class InternalData {
		shared uint refCount;
		Instance[] instances;

		~this() {
			foreach(instance; instances) {
				allocator.dispose(instance.retriever);
				allocator.dispose(instance.consumers);
			}
			allocator.dispose(instances);
		}

		struct Instance {
			EventLoopSourceRetriever retriever;
			EventLoopConsumer[] consumers;
		}
	}
}