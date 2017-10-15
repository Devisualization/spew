module cf.spew.implementation.manager;
import cf.spew.event_loop.defs;
import cf.spew.event_loop.base;
import cf.spew.events.defs;
import devisualization.util.core.memory.managed;
import std.experimental.allocator;
import core.thread : ThreadID, Thread;
import core.time : Duration, seconds;

class EventLoopManager_Impl : EventLoopManager_Base {
	import containers.hashmap;
	import containers.dynamicarray;
	import core.atomic;
	import core.sync.mutex;

	protected {
		Duration hintSourceTimeout;

		shared(Mutex) mutex_sourcesAlter, mutex_consumersAlter;
		DynamicArray!(EventLoopSource, shared(ISharedAllocator)) sources;
		DynamicArray!(EventLoopConsumer, shared(ISharedAllocator)) consumers;

		Mutex mutex_threadData;
		HashMap!(ThreadID, InternalData, shared(ISharedAllocator)) threadData;
	}

	this(shared(ISharedAllocator) allocator = processAllocator(), ThreadID mainThreadID = Thread.getThis().id) shared {
		super(allocator, mainThreadID);

		this.hintSourceTimeout = 0.seconds;
		this.onErrorDelegate = &onErrorDelegateDefaultImpl;

		this.sources = cast(shared)DynamicArray!(EventLoopSource, shared(ISharedAllocator))(allocator);
		this.consumers = cast(shared)DynamicArray!(EventLoopConsumer, shared(ISharedAllocator))(allocator);

		this.mutex_sourcesAlter = allocator.make!(shared(Mutex));
		this.mutex_consumersAlter = allocator.make!(shared(Mutex));
		this.mutex_threadData = allocator.make!(shared(Mutex));

		this.threadData = cast(shared)HashMap!(ThreadID, InternalData, shared(ISharedAllocator))(allocator);
	}

	void addConsumers(shared(EventLoopConsumer)[] toAdd...) shared {
		synchronized(mutex_consumersAlter) {
			foreach(v; toAdd) {
				bool dontAdd;
				foreach(csmr; cast()consumers) {
					if (csmr == v) {
						dontAdd = true;
					}
				}

				if (!dontAdd)
					cast()consumers ~= cast()v;
			}
		}
	}

	void addSources(shared(EventLoopSource)[] toAdd...) shared {
		synchronized(mutex_sourcesAlter) {
			foreach(v; toAdd) {
				bool dontAdd;
				EventSource id = v.identifier;

				foreach(src; cast()sources) {
					if ((cast(shared)src) == v || (cast(shared)src).identifier == id) {
						dontAdd = true;
					}
				}

				if (!dontAdd)
					cast()sources ~= cast()v;
			}
		}
	}

	void clearConsumers() shared {
		synchronized(mutex_consumersAlter) {
			while(!(cast()consumers).empty) (cast()consumers).removeBack;
		}
	}

	void clearSources() shared {
		synchronized(mutex_sourcesAlter) {
			while(!(cast()sources).empty) (cast()sources).removeBack;
		}
	}

	void setSourceTimeout(Duration duration = 0.seconds) shared {
		this.hintSourceTimeout = duration;
	}

	string describeRules() shared { 
		import std.array : appender;
		import std.conv : text;

		auto result = appender!string;
		size_t countEle = (cast()threadsState).keys.length;
		result.reserve(100 * countEle + 1);

		result ~= "There are currently ";
		result ~= countEle.text;
		result ~= " threads registered with the event loop manager.\n";

		result ~= "The thread ids are: [";
		if (countEle > 3)
			result ~= "\n\t";
		foreach(i, tid; (cast()threadsState).keys) {
			result ~= tid.text;
			if (i + 1 < countEle)
				result ~= ", ";
		}
		result ~= "]\n\n";

		foreach(tid; (cast()threadsState).keys) {
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
		result ~= (cast()threadsState)[id].text;
		result ~= "\n";

		InternalData data = (cast()threadData)[id];
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
				atomicOp!"-="((cast()threadData)[id].refCount, 1);
				if (atomicLoad((cast()threadData)[id].refCount) == 0)
					(cast()threadData).remove(id);
				(cast()threadsState).remove(id);
			}
		}

		void* initializeImpl(ThreadID threadId) shared {
			shared(InternalData) ret = allocator.make!(shared(InternalData))(allocator);
			ret.refCount = 1;

			bool isOnMainThread = isMainThread(threadId);
			size_t sourceCount;

			foreach(source; cast()sources) {
				if ((isOnMainThread && (cast(shared)source).onMainThread) || (!isOnMainThread && (cast(shared)source).onAdditionalThreads)) {
					sourceCount++;
				}
			}

			shared(EventLoopConsumer)[] allConsumers = allocator.makeArray!(shared(EventLoopConsumer))((cast()consumers).length);
			ret.instances = allocator.makeArray!(shared(InternalData.Instance))(sourceCount);

			size_t i, j;
			foreach(source; cast()sources) {
				size_t k;

				foreach(consumer; cast()consumers) {
					if (((isOnMainThread && (cast(shared)consumer).onMainThread) || (!isOnMainThread && (cast(shared)consumer).onAdditionalThreads)) &&
						((cast(shared)consumer).pairOnlyWithSource.isNull || (cast(shared)consumer).pairOnlyWithSource.get == (cast(shared)source).identifier)) {
						allConsumers[k] = cast(shared)consumer;
						k++;
					}

					j++;
				}

				shared(EventLoopConsumer)[] allConsumersSlice = allConsumers[0 .. k];
				short lastPriority = byte.min;
				
				ret.instances[i].source = (cast(shared)source);
				ret.instances[i].retriever = (cast(shared)source).nextEventGenerator(allocator);
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
				(cast()threadData)[threadId] = cast()ret;
				(cast()threadsState)[threadId] = ThreadState.Initialized;
				return cast(void*)ret;
			}
		}

		void executeImpl(ThreadID threadId, void* ctx) shared {
			InternalData data = cast(InternalData)ctx;
			atomicOp!"+="(data.refCount, 1);

			while((cast()threadsState)[threadId] != ThreadState.Stop) {
				foreach(instance; data.instances) {
					Event event;
					while(instance.retriever.nextEvent(event)) {
						bool handled;
						if (event.type.value > 0) {
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