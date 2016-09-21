///
module cf.spew.event_loop.defs;
import cf.spew.events.defs : EventSource, Event, EventType;
import std.experimental.allocator : IAllocator;
import core.time : Duration, seconds;
import core.thread : ThreadID, Thread;

///
enum ThreadState : ubyte {
	/// /error/ /error/ /error/
	Unknown,
	
	/// not running and not initialized
	Uninitialized,

	/// Ready to go
	Initialized,

	/// running
	Started,
	
	/// is initialized but not running
	Stopped,
	Stop
}

///
interface IEventLoopThing {
	@property {
		///
		bool onMainThread();
		///
		bool onAdditionalThreads();
		///
		string description();
	}
}

///
interface EventLoopSource : IEventLoopThing {
	@property {
		///
		EventSource identifier();
	}
	
	///
	EventLoopSourceRetriever nextEventGenerator(IAllocator);
}

///
interface EventLoopConsumer : IEventLoopThing {
	import std.typecons : Nullable;
	
	@property {
		///
		Nullable!EventSource pairOnlyWithSource();
		
		// prefix for the event types
		EventType pairOnlyWithEvents();
		
		/// If you transform and not consume, make this negative, 0 to just "see" it and do nothing.
		byte priority();
	}
	
	/**
	 * Returns:
	 * 		If the event is consumed
	 */
	bool processEvent(ref Event event);
}

///
interface EventLoopSourceRetriever {
	/**
	 * Returns:
	 * 		If a valid event
	 */
	bool nextEvent(ref Event event);
	
	///
	void handledEvent(ref Event event);
	///
	void unhandledEvent(ref Event event);
	///
	void handledErrorEvent(ref Event event);
	
	///
	void hintTimeout(Duration timeout);
}

///
interface IEventLoopManager {
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
	
	/// Is the event loop running on the given thread?
	bool runningOnThreadFor(ThreadID id = Thread.getThis().id);

	/// Stop the event loop only on the main thread
	void stopMainThread();
	
	/// Stop the event loop only on auxillary threads
	void stopAuxillaryThreads();
	
	/// Stop the event loop on all threads
	void stopAllThreads();
	
	/// Stop the event loop for the given thread
	void stopThreadFor(ThreadID id = Thread.getThis().id);

	/// For each source, set the timeout hint
	void setSourceTimeout(Duration duration = 0.seconds);
	
	/// Notifies that this thread should be "registered"
	void notifyOfThread(ThreadID id = Thread.getThis().id);
	
	/// Describes the rules for every thread
	string describeRules();

	/// Describes the rules for the thread provided (default current)
	string describeRulesFor(ThreadID id = Thread.getThis().id);

	/// Starts the execution of the event loop
	void execute();

	// register a delegate to execute should an exception be thrown during event loop execution
	void registerOnErrorDelegate(void delegate(ThreadID, Exception));

	final {
		/// Is the event loop running on the current thread?
		bool runningOnCurrentThread() { return runningOnThreadFor; }
		/// Stop the event loop for the current thread
		void stopCurrentThread() { stopThreadFor; }
	}
}
