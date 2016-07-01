/**
 * A generic event loop that supports a main thread and subsequent auxillary threads.
 * 
 * If you only have one source + consumer, you probably want to use them explicitly as this
 *  has way too much overhead for that usecase.
 */
module cf.spew.event_loop.manager;
public import cf.spew.event_loop.defs;
import core.thread : thread_isMainThread;

void execute(bool isMainThread = thread_isMainThread()) {
	// Execution doesn't just happen in a vacuum.
	// It happens with other threads and apis running
	//  so it is crucial to understand are we the
	//  main event loop or not.
	
	// Some sources and consumers should only execute
	//  on the main loop or solely on per thread
	//  and quite often are paired.
	
	// But we also don't want to figure out the entire
	//  execution process and flow every time we run this.
	// So if we have updated the input since last execution,
	//  then we should go ahead and work it out (only do this once so synchronized!)
	
	initCall();

	if (isMainThread) {
		executeMainThread();
	} else {
		executeNonMainThread();
	}
}

//

void stopExecution(bool stopWithMainThread=true) {
	atomicStore(stopAuxillaryThreads, true);
	
	if (stopWithMainThread)
		atomicStore(stopMainThreadOnly, true);
}

void stopExecutingOnlyMainThread() {
	atomicStore(stopMainThreadOnly, true);
}

//

void addSource(EventLoopSource[] source...) {
	import std.experimental.allocator : expandArray;
	initCall();
	
	synchronized(inUpdateIteration) {
		_allocator.expandArray(sources, source.length);
		sources[$ - source.length .. $] = source[];
		atomicStore(updatedSinceLastExecute, true);
	}
}

void addConsumer(EventLoopConsumer[] consumer...) {
	import std.experimental.allocator : expandArray;
	initCall();

	synchronized(inUpdateIteration) {
		_allocator.expandArray(consumers, consumer.length);
		consumers[$ - consumer.length .. $] = consumer[];
		atomicStore(updatedSinceLastExecute, true);
	}
}

void clearSources() {
	import std.experimental.allocator : dispose;
	initCall();

	synchronized(inUpdateIteration) {
		_allocator.dispose(sources);
		atomicStore(updatedSinceLastExecute, true);
	}
}

void clearConsumers() {
	import std.experimental.allocator : dispose;
	initCall();
	
	synchronized(inUpdateIteration) {
		_allocator.dispose(consumers);
		atomicStore(updatedSinceLastExecute, true);
	}
}

bool isMainThreadRunning() { return mainThreadRunning; }
uint countAuxilaryThreadsRunning() { return auxillaryThreadsRunning; }

//

private {
	import std.experimental.allocator : IAllocator;
	import core.sync.mutex;

	__gshared {
		IAllocator _allocator;
		Mutex inUpdateIteration;

		EventLoopSource[] sources;
		EventLoopConsumer[] consumers;
	}

	shared {
		bool stopMainThreadOnly, stopAuxillaryThreads;

		bool mainThreadRunning;
		uint auxillaryThreadsRunning;

		bool updatedSinceLastExecute;
		Impl implementationMainloop, implementationAuxillaryLoops;
	}

	void init() {
		import std.experimental.allocator : processAllocator;

		inUpdateIteration = new Mutex;
		_allocator = processAllocator();
	}

	pragma(inline, true)
	void initCall() {
		if (inUpdateIteration is null)
			init();
	}
}

//

private:
public import cf.spew.events.defs;
import core.atomic : atomicLoad, atomicStore, atomicOp;

final class Impl {
	struct Step {
		bool delegate(ref Event) source;
		bool delegate(ref Event)[] consumers;
	}

	Step[] steps;

	// life time management

	shared uint refCount;
	
	this() shared {
		atomicOp!"+="(refCount, 1);
	}
	
	~this() {
		import std.experimental.allocator : dispose;

		foreach(step; steps) {
			_allocator.dispose(step.consumers);
		}

		_allocator.dispose(steps);
	}

	void addRef() {
		atomicOp!"+="(refCount, 1);
	}
	
	void removeRef() {
		import std.experimental.allocator : dispose;

		if (refCount == 1) {
			_allocator.dispose(this);
		} else {
			atomicOp!"-="(refCount, 1);
		}
	}
}

void performEventImplUpdate() {
	import std.experimental.allocator : make, makeArray;
	
	if (atomicLoad(updatedSinceLastExecute)) {
		synchronized(inUpdateIteration) {
			if (!atomicLoad(updatedSinceLastExecute))
				return;

			if (implementationMainloop !is null)
				(cast()implementationMainloop).removeRef;
			if (implementationAuxillaryLoops !is null)
				(cast()implementationAuxillaryLoops).removeRef;
			
			shared Impl mainThreadImpl = _allocator.make!(shared Impl);
			shared Impl auxillaryThreadsImpl = _allocator.make!(shared Impl);


			size_t mtSc, atSc;
			foreach(source; sources) {
				if (source.onMainThread)
					mtSc++;
				if (source.onAdditionalThreads)
					atSc++;
			}

			mainThreadImpl.steps = cast(shared)_allocator.makeArray!(Impl.Step)(mtSc);
			auxillaryThreadsImpl.steps = cast(shared)_allocator.makeArray!(Impl.Step)(atSc);

			size_t mtSi, atSi;
			foreach(source; sources) {
				EventSource sourceId = source.identifier;

				size_t mtCc, atCc;
				foreach(consumer; consumers) {
					auto consumerToPairWith = consumer.pairOnlyWithSource;

					if (!consumerToPairWith.isNull && consumerToPairWith.get == sourceId) {
						if (consumer.onMainThread) {
							mtCc++;
						}
						
						if (consumer.onAdditionalThreads) {
							atCc++;
						}
					}
				}

				if (source.onMainThread) {
					mainThreadImpl.steps[mtSi].source = &source.nextEvent;
					mainThreadImpl.steps[mtSi].consumers = cast(shared)_allocator.makeArray!(bool delegate(ref Event))(mtCc);

					size_t mtCi;
					byte lastPriority = byte.min;
					
					while(mtCi < mtCc) {
						foreach(consumer; consumers) {
							auto consumerToPairWith = consumer.pairOnlyWithSource;
							
							if (!consumerToPairWith.isNull && consumerToPairWith.get == sourceId) {
								if (consumer.onMainThread && lastPriority <= consumer.priority) {
									mainThreadImpl.steps[mtSi].consumers[mtCi] = cast(shared)&consumer.processEvent;
									lastPriority = consumer.priority;
									mtCi++;
								}
							}
						}
					}

					mtSi++;
				}
				
				if (source.onAdditionalThreads) {
					auxillaryThreadsImpl.steps[atSi].source = &source.nextEvent;
					auxillaryThreadsImpl.steps[mtSi].consumers = cast(shared)_allocator.makeArray!(bool delegate(ref Event))(mtCc);

					size_t atCi;
					byte lastPriority = byte.min;

					while(atCi < mtCc) {
						foreach(consumer; consumers) {
							auto consumerToPairWith = consumer.pairOnlyWithSource;
							
							if (!consumerToPairWith.isNull && consumerToPairWith.get == sourceId) {
								if (consumer.onAdditionalThreads && lastPriority <= consumer.priority) {
									auxillaryThreadsImpl.steps[atSi].consumers[atCi] = cast(shared)&consumer.processEvent;
									lastPriority = consumer.priority;
									atCi++;
								}
							}
						}
					}

					atSi++;
				}
			}
			
			implementationMainloop = mainThreadImpl;
			implementationAuxillaryLoops = auxillaryThreadsImpl;

			atomicStore(updatedSinceLastExecute, false);
		}
	}
}

void executeMainThread() {
	assert(!atomicLoad(mainThreadRunning));
	atomicStore(mainThreadRunning, true);

	Impl impl = atomicLoad(implementationMainloop);
	impl.addRef;
	
	for(;;) {
		if (atomicLoad(stopMainThreadOnly)) {
			atomicStore(stopMainThreadOnly, false);
			break;
		}
		
		performEventImplUpdate();
		
		//

		Event event = void;

	F1: foreach(step; impl.steps) {
			while(step.source(event)) {
				foreach(consumer; step.consumers) {
					if (consumer(event))
						continue F1;
				}
			}
		}
	}
	
	impl.removeRef;
	atomicStore(mainThreadRunning, false);
}

void executeNonMainThread() {
	atomicOp!"+="(auxillaryThreadsRunning, 1);
	
	Impl impl = atomicLoad(implementationAuxillaryLoops);
	impl.addRef;

	for(;;) {
		if (atomicLoad(stopAuxillaryThreads)) {
			atomicStore(stopAuxillaryThreads, false);
			break;
		}

		performEventImplUpdate();
		
		//

		Event event = void;

	F1: foreach(step; impl.steps) {
			while(step.source(event)) {
				foreach(consumer; step.consumers) {
					if (consumer(event))
						continue F1;
				}
			}
		}
	}

	impl.removeRef;
	atomicOp!"-="(auxillaryThreadsRunning, 1);
}