﻿module cf.spew.implementation.manager;
import cf.spew.event_loop.defs;
import cf.spew.event_loop.base;
import cf.spew.events.defs;
import std.experimental.allocator;
import core.thread : ThreadID, Thread;
import core.time : Duration, seconds;

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

	string describeRules() { assert(0); }
	string describeRulesFor(ThreadID id = Thread.getThis().id) { assert(0); }

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