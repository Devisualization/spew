module cf.spew.event_loop.defs;
import cf.spew.events.defs : EventSource, Event;

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

	/**
	 * Returns:
	 * 		If a valid event
	 */
	bool nextEvent(ref Event event);
}

interface EventLoopConsumer : IEventLoopThing {
	import std.typecons : Nullable;
	
	@property {
		Nullable!EventSource pairOnlyWithSource();

		/// If you transform and not consume, make this negative
		byte priority();
	}

	/**
	 * Returns:
	 * 		If the event is consumed
	 */
	bool processEvent(ref Event event);
}