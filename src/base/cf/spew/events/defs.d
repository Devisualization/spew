module cf.spew.events.defs;
import cf.spew.events.windowing;

/**
 * 
 */
struct Event {
	///
	EventSource source;
	///
	EventType type;
	
	/// Context e.g. window handle
	union {
		///
		void* wellData1Ptr;
		///
		size_t wellData1Value;
	}

	///
	union {
		///
		void* wellData2Ptr;
		///
		size_t wellData2Value;
	}

	///
	union {
		///
		void* wellData3Ptr;
		///
		size_t wellData3Value;
	}

	union {
		version(Windows) {
			import cf.spew.events.winapi;

			///
			WinAPI_Events winapi;
		}

		///
		Windowing_Events windowing;

		// TODO
	}
}

/**
 * 
 */
union EventSource {
	private char[8] text_;

	///
	ulong value;
	alias value this;

	/**
	 * 
	 */
	static EventSource from(string from)
	in {
		assert(from.length <= 8);
	} body {
		char[8] ret = ' ';
		
		if (from.length > 0)
			ret[0 .. from.length] = from[];
		return EventSource(ret);
	}

	///
	string toString() const {
		import std.string : lastIndexOf;
		
		ptrdiff_t i = text_.lastIndexOf(' ');
		
		if (i <= 0)
			return null;
		else
			return cast(immutable)text_[0 .. i];
	}
}

///
alias EventType = EventSource;
