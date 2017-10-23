/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.event_loop.defs;
import cf.spew.events.defs : EventSource, Event, EventType;
import std.experimental.allocator : ISharedAllocator;
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
		bool onMainThread() shared;
		///
		bool onAdditionalThreads() shared;
		///
		string description() shared;
	}
}

///
interface EventLoopSource : IEventLoopThing {
	@property {
		///
		EventSource identifier() shared;
	}
	
	///
	shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator)) shared;
}

///
interface EventLoopConsumer : IEventLoopThing {
	import std.typecons : Nullable;

	@property {
		///
		Nullable!EventSource pairOnlyWithSource() shared;
		
		// prefix for the event types
		EventType pairOnlyWithEvents() shared;

		/// If you transform and not consume, make this negative, 0 to just "see" it and do nothing.
		byte priority() shared;
	}
	
	/**
	 * Returns:
	 * 		If the event is consumed
	 */
	bool processEvent(ref Event event) shared;
}

///
interface EventLoopSourceRetriever {
	/**
	 * If the events type value is 0, then don't search for a consumer.
	 * 
	 * Returns:
	 * 		If a valid event
	 */
	bool nextEvent(ref Event event) shared;
	
	///
	void handledEvent(ref Event event) shared;
	///
	void unhandledEvent(ref Event event) shared;
	///
	void handledErrorEvent(ref Event event) shared;
	
	///
	void hintTimeout(Duration timeout) shared;
}

///
interface IEventLoopManager {
	/**
	 * Adds the provided consumers to the list.
	 * 
	 * If a consumer is already stored, it will be ignored.
	 */
	void addConsumers(shared(EventLoopConsumer)[]...) shared;
	
	/**
	 * Adds the provided sources to the list.
	 * 
	 * If a source is already stored, it will be ignored.
	 */
	void addSources(shared(EventLoopSource)[]...) shared;
	
	/// Removes all consumers from the list.
	void clearConsumers() shared;
	
	/// Removes all the sources from the list.
	void clearSources() shared;
	
	/// Does the main thread have an event loop executing?
	bool runningOnMainThread() shared;
	
	/// Does any of the auxillary threads have an event loop executing?
	bool runningOnAuxillaryThreads() shared;
	
	/// How many of the auxillary threads have an event loop executing? 
	uint countRunningOnAuxillaryThread() shared;
	
	/// Is the event loop running on the given thread?
	bool runningOnThreadFor(ThreadID id = Thread.getThis().id) shared;

	/// Stop the event loop only on the main thread
	void stopMainThread() shared;
	
	/// Stop the event loop only on auxillary threads
	void stopAuxillaryThreads() shared;
	
	/// Stop the event loop on all threads
	void stopAllThreads() shared;
	
	/// Stop the event loop for the given thread
	void stopThreadFor(ThreadID id = Thread.getThis().id) shared;

	/// For each source, set the timeout hint
	void setSourceTimeout(Duration duration = 0.seconds) shared;
	
	/// Notifies that this thread should be "registered"
	void notifyOfThread(ThreadID id = Thread.getThis().id) shared;
	
	/// Describes the rules for every thread
	string describeRules() shared;

	/// Describes the rules for the thread provided (default current)
	string describeRulesFor(ThreadID id = Thread.getThis().id) shared;

	/// Starts the execution of the event loop
	void execute() shared;

	// register a delegate to execute should an exception be thrown during event loop execution
	void registerOnErrorDelegate(void delegate(ThreadID, Exception) shared) shared;

	final {
		/// Is the event loop running on the current thread?
		bool runningOnCurrentThread() shared { return runningOnThreadFor; }
		/// Stop the event loop for the current thread
		void stopCurrentThread() shared { stopThreadFor; }
	}
}
