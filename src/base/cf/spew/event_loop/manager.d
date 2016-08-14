/**
 * A generic event loop that supports a main thread and subsequent auxillary threads.
 * 
 * If you only have one source + consumer, you probably want to use them explicitly as this
 *  has way too much overhead for that usecase.
 */
module cf.spew.event_loop.manager;
public import cf.spew.event_loop.defs;
import core.thread : thread_isMainThread;
import core.time : Duration, seconds;

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
	if (atomicLoad(auxillaryThreadsRunning) > 0)
		atomicStore(stopAuxillaryThreads, true);
	
	if (atomicLoad(mainThreadRunning) && stopWithMainThread)
		atomicStore(stopMainThreadOnly, true);
}

void stopExecutingOnlyMainThread() {
	if (atomicLoad(mainThreadRunning))
		atomicStore(stopMainThreadOnly, true);
}

//

void addSource(EventLoopSource[] source...) {
	import std.experimental.allocator : expandArray;
	initCall();

	// TODO: are we already in?

	synchronized(inUpdateIteration) {
		_allocator.expandArray(sources, source.length);
		sources[$ - source.length .. $] = source[];
		atomicStore(updatedSinceLastExecute, true);
	}
}

void addConsumer(EventLoopConsumer[] consumer...) {
	import std.experimental.allocator : expandArray;
	initCall();

	// TODO: are we already in?

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

void setPerSourceTimeout(Duration timeout = 20.seconds) {
	perSourceTimeout = timeout;
}

//

private {
	import std.experimental.allocator : IAllocator;
	import core.sync.mutex;

	__gshared {
		IAllocator _allocator;
		Mutex inUpdateIteration;

		Duration perSourceTimeout;

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
	EventLoopSource[] sources;
	bool delegate(ref Event)[][] consumers;

	// life time management

	shared uint refCount;
	
	this() shared {
		atomicOp!"+="(refCount, 1);
	}
	
	~this() {
		import std.experimental.allocator : dispose;

		foreach(step; consumers) {
			_allocator.dispose(step);
		}

		_allocator.dispose(consumers);
		_allocator.dispose(sources);
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

			mainThreadImpl.sources = cast(shared)_allocator.makeArray!EventLoopSource(mtSc);
			auxillaryThreadsImpl.sources = cast(shared)_allocator.makeArray!EventLoopSource(atSc);

			mainThreadImpl.consumers = cast(shared)_allocator.makeArray!(bool delegate(ref Event)[])(mtSc);
			auxillaryThreadsImpl.consumers = cast(shared)_allocator.makeArray!(bool delegate(ref Event)[])(atSc);

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
					mainThreadImpl.sources[mtSi] = cast(shared)source;
					mainThreadImpl.consumers[mtSi] = cast(shared)_allocator.makeArray!(bool delegate(ref Event))(mtCc);

					size_t mtCi;
					short lastPriority = byte.min;
					
					while(mtCi < mtCc) {
						foreach(consumer; consumers) {
							auto consumerToPairWith = consumer.pairOnlyWithSource;
							
							if (!consumerToPairWith.isNull && consumerToPairWith.get == sourceId) {
								if (consumer.onMainThread && lastPriority <= consumer.priority) {
									mainThreadImpl.consumers[mtSi][mtCi] = cast(shared)&consumer.processEvent;
									lastPriority = consumer.priority;
									mtCi++;
								}
							}
						}

						lastPriority++;
					}

					mtSi++;
				}
				
				if (source.onAdditionalThreads) {
					auxillaryThreadsImpl.sources[atSi] = cast(shared)source;
					auxillaryThreadsImpl.consumers[atSi] = cast(shared)_allocator.makeArray!(bool delegate(ref Event))(mtCc);

					size_t atCi;
					short lastPriority = byte.min;

					while(atCi < mtCc) {
						foreach(consumer; consumers) {
							auto consumerToPairWith = consumer.pairOnlyWithSource;
							
							if (!consumerToPairWith.isNull && consumerToPairWith.get == sourceId) {
								if (consumer.onAdditionalThreads && lastPriority <= consumer.priority) {
									auxillaryThreadsImpl.consumers[atSi][atCi] = cast(shared)&consumer.processEvent;
									lastPriority = consumer.priority;
									atCi++;
								}
							}
						}

						lastPriority++;
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
	import std.experimental.allocator : makeArray, dispose;

	assert(!atomicLoad(mainThreadRunning));
	atomicStore(mainThreadRunning, true);

	Impl impl;
	EventLoopSourceRetriever[] sources;

	for(;;) {
		if (atomicLoad(stopMainThreadOnly)) {
			atomicStore(stopMainThreadOnly, false);
			break;
		}

		performEventImplUpdate();

		auto impl2 = atomicLoad(implementationMainloop);
		if (impl !is impl2) {
			if (impl !is null)
				impl.removeRef;

			impl = impl2;
			impl.addRef;

			sources = _allocator.makeArray!EventLoopSourceRetriever(impl.sources.length);
			foreach(i, source; impl.sources) {
				sources[i] = source.nextEventGenerator(_allocator);
				sources[i].hintTimeout(perSourceTimeout);
			}
		}

		//

		Event event;

	F1: foreach(i, source; sources) {
			while(source.nextEvent(event)) {
				foreach(consumer; impl.consumers[i]) {
					if (consumer(event))
						goto HandledEvent;
				}
			}

		UnhandledEvent:
			source.unhandledEvent(event);
			continue;
		HandledEvent:
			source.handledEvent(event);
			continue;
		}
	}

	impl.removeRef;
	_allocator.dispose(sources);
	atomicStore(mainThreadRunning, false);
}

void executeNonMainThread() {
	import std.experimental.allocator : makeArray, dispose;
	atomicOp!"+="(auxillaryThreadsRunning, 1);
	
	Impl impl;
	EventLoopSourceRetriever[] sources;

	for(;;) {
		if (atomicLoad(stopAuxillaryThreads)) {
			atomicStore(stopAuxillaryThreads, false);
			break;
		}

		performEventImplUpdate();
		
		auto impl2 = atomicLoad(implementationAuxillaryLoops);
		if (impl !is impl2) {
			if (impl !is null)
				impl.removeRef;
			
			impl = impl2;
			impl.addRef;
			
			sources = _allocator.makeArray!EventLoopSourceRetriever(impl.sources.length);
			foreach(i, source; impl.sources) {
				sources[i] = source.nextEventGenerator(_allocator);
				sources[i].hintTimeout(perSourceTimeout);
			}
		}
		
		//

		Event event;

	F1: foreach(i, source; sources) {
			while(source.nextEvent(event)) {
				foreach(consumer; impl.consumers[i]) {
					if (consumer(event))
						goto HandledEvent;
				}
			}
			
		UnhandledEvent:
			source.unhandledEvent(event);
			continue;
		HandledEvent:
			source.handledEvent(event);
			continue;
		}
	}

	impl.removeRef;
	_allocator.dispose(sources);
	atomicOp!"-="(auxillaryThreadsRunning, 1);
}