module cf.spew.implementation.manager;
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

		shared(Mutex) mutex_sourcesAlter, mutex_consumersAlter;
		shared(SharedList!(shared(EventLoopSource))) sources;
		shared(SharedList!(shared(EventLoopConsumer))) consumers;

		Mutex mutex_threadData;
		shared(SharedMap!(ThreadID, InternalData)) threadData;
	}

	this(shared(ISharedAllocator) allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) shared {
		super(allocator, mainThreadID);

		this.hintSourceTimeout = 0.seconds;
		this.onErrorDelegate = &onErrorDelegateDefaultImpl;

		this.sources = SharedList!(shared(EventLoopSource))(allocator);
		this.consumers = SharedList!(shared(EventLoopConsumer))(allocator);

		this.mutex_sourcesAlter = allocator.make!(shared(Mutex));
		this.mutex_consumersAlter = allocator.make!(shared(Mutex));
		this.mutex_threadData = allocator.make!(shared(Mutex));

		this.threadData = SharedMap!(ThreadID, InternalData)(allocator);
	}

	void addConsumers(shared(EventLoopConsumer)[] toAdd...) shared {
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

	void addSources(shared(EventLoopSource)[] toAdd...) shared {
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

	void clearConsumers() shared {
		synchronized(mutex_consumersAlter) {
			consumers.length = 0;
		}
	}

	void clearSources() shared {
		synchronized(mutex_sourcesAlter) {
			sources.length = 0;
		}
	}

	void setSourceTimeout(Duration duration = 0.seconds) shared {
		this.hintSourceTimeout = duration;
	}

	string describeRules() shared { 
		import std.array : appender;
		import std.conv : text;

		auto result = appender!string;
		size_t countEle = threadsState.keys.length;
		result.reserve(100 * countEle + 1);

		result ~= "There are currently ";
		result ~= countEle.text;
		result ~= " threads registered with the event loop manager.\n";

		result ~= "The thread ids are: [";
		if (countEle > 3)
			result ~= "\n\t";
		foreach(i, tid; threadsState.keys) {
			result ~= tid.text;
			if (i + 1 < countEle)
				result ~= ", ";
		}
		result ~= "]\n\n";

		foreach(tid; threadsState.keys) {
			result ~= describeRulesFor(tid);
		}

		return result.data;
	}

	string describeRulesFor(ThreadID id = Thread.getThis().id) shared {
		import std.array : appender;
		import std.conv : text;
		import std.string : lineSplitter, KeepTerminator;

		initializeImpl(id);

		auto result = appender!string;

		result ~= "Thread id: ";
		result ~= id.text;

		if (isMainThread(id))
			result ~= " [MAIN] {\n";
		else
			result ~= " [AUXILLARY] {\n";

		result ~= "\tCurrent state: ";
		result ~= threadsState[id].text;
		result ~= "\n";

		shared InternalData data = threadData[id];
		atomicOp!"+="(data.refCount, 1);

		if (data !is null) {
			result ~= "\n\tSources:\n";
			foreach(instance; data.instances) {
				result ~= "\t\t- [";
				result ~= instance.source.identifier.toString;
				result ~= "] ";
				result ~= (cast(Object)instance.source).classinfo.name;
				result ~= ":\n";

				foreach(line; lineSplitter!(KeepTerminator.yes)(instance.source.description)) {
					result ~= "\t\t\t";
					result ~= line;
				}
				result ~= "\n";
			}

			foreach(instance; data.instances) {
				result ~= "\tSource [";
				result ~= instance.source.identifier.toString;
				result ~= "] {\n";

				foreach(consumer; instance.consumers) {
					result ~= "\t\t- ";
					result ~= (cast(Object)consumer).classinfo.name;
					if (consumer.onMainThread)
						result ~= " [MAIN]";
					if (consumer.onAdditionalThreads)
						result ~= " [AUXILLARY]";
					result ~= "\n";

					result ~= "\t\t\t[PRIORITY ";
					result ~= consumer.priority.text;
					result ~= "]";

					if (!consumer.pairOnlyWithSource.isNull) {
						result ~= " [ONLY SOURCE ";
						result ~= consumer.pairOnlyWithSource.get.toString;
						result ~= "]";
					}

					if (consumer.pairOnlyWithEvents != EventType.all) {
						result ~= " [ONLY EVENTS ";
						result ~= consumer.pairOnlyWithEvents.toString;
						result ~= "]";
					}

					result ~= ":\n";

					foreach(line; lineSplitter!(KeepTerminator.yes)(consumer.description)) {
						result ~= "\t\t\t";
						result ~= line;
					}
					result ~= "\n";
				}
				result ~= "\n\t}\n";
			}
		}

		atomicOp!"-="(data.refCount, 1);
		if (atomicLoad(data.refCount) == 0)
			allocator.dispose(data);

		result ~= "}\n";
		return result.data;
	}

	protected {
		void onErrorDelegateDefaultImpl(ThreadID, Exception) shared {}
	}

	protected override {
		void cleanupRemovingImpl(ThreadID id) shared {
			synchronized(mutex_threadData) {
				atomicOp!"-="(threadData[id].refCount, 1);
				if (atomicLoad(threadData[id].refCount) == 0)
					threadData.remove(id);
				threadsState.remove(id);
			}
		}

		void* initializeImpl(ThreadID threadId) shared {
			shared(InternalData) ret = allocator.make!(shared(InternalData))(allocator);
			ret.refCount = 1;

			bool isOnMainThread = isMainThread(threadId);
			size_t sourceCount;

			foreach(source; sources) {
				if ((isOnMainThread && source.onMainThread) || (!isOnMainThread && source.onAdditionalThreads)) {
					sourceCount++;
				}
			}

			shared(EventLoopConsumer)[] allConsumers = allocator.makeArray!(shared(EventLoopConsumer))(consumers.length);
			ret.instances = allocator.makeArray!(shared(InternalData.Instance))(sourceCount);

			size_t i, j;
			foreach(source; sources) {
				size_t k;

				foreach(consumer; consumers) {
					if (((isOnMainThread && consumer.onMainThread) || (!isOnMainThread && consumer.onAdditionalThreads)) &&
						(consumer.pairOnlyWithSource.isNull || consumer.pairOnlyWithSource.get == source.identifier)) {
						allConsumers[k] = consumer;
						k++;
					}

					j++;
				}

				shared(EventLoopConsumer)[] allConsumersSlice = allConsumers[0 .. k];
				short lastPriority = byte.min;
				
				ret.instances[i].source = source;
				ret.instances[i].retriever = source.nextEventGenerator(allocator);
				ret.instances[i].retriever.hintTimeout(hintSourceTimeout);
				ret.instances[i].consumers = allocator.makeArray!(shared(EventLoopConsumer))(allConsumersSlice.length);

				size_t countAddedSoFar;
				while (countAddedSoFar < allConsumersSlice.length) {
					foreach(consumer; allConsumersSlice) {
						if (consumer.priority == lastPriority) {
							ret.instances[i].consumers[countAddedSoFar] = consumer;
							countAddedSoFar++;
						}
					}
					
					lastPriority++;
				}

				i++;
			}

			allocator.dispose(cast(EventLoopConsumer[])allConsumers);

			synchronized(mutex_threadData) {
				threadData[threadId] = ret;
				threadsState[threadId] = ThreadState.Initialized;
				return cast(void*)ret;
			}
		}

		void executeImpl(ThreadID threadId, void* ctx) shared {
			InternalData data = cast(InternalData)ctx;
			atomicOp!"+="(data.refCount, 1);

			while(threadsState[threadId] != ThreadState.Stop) {
				foreach(instance; data.instances) {
					Event event;
					while(instance.retriever.nextEvent(event)) {
						bool handled;

						try {
							foreach(consumer; instance.consumers) {
								if (consumer.pairOnlyWithEvents == event.type) {
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
}

private final class InternalData {
	shared uint refCount;
	Instance[] instances;
	shared(ISharedAllocator) allocator;

	this(shared(ISharedAllocator) allocator) shared {
		this.allocator = allocator;
	}

	~this() {
		foreach(instance; instances) {
			allocator.dispose(instance.retriever);
			allocator.dispose(cast(EventLoopConsumer[])instance.consumers);
		}
		allocator.dispose(instances);
	}
	
	struct Instance {
		shared(EventLoopSourceRetriever) retriever;
		shared(EventLoopSource) source;
		shared(EventLoopConsumer)[] consumers;
	}
}