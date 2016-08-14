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