///
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
struct EventSource {
	//private char[8] text_;

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
		import std.conv : to;
		char[8] ret = ' ';
		
		if (from.length > 0)
			ret[0 .. from.length] = from[];

		ulong reti;

		foreach(i; 0 .. 8) {
			reti *= 256;
			reti += ret[7-i];
		}

		return EventSource(reti);
	}

	///
	@property static EventSource all() {
		return EventSource(0x2020202020202020);
	}

	///
	string toString() const {
		import std.string : lastIndexOf;

		char[8] text;
		ulong temp = value;
		foreach(i; 0 .. 8) {
			text[i] = cast(char)temp;

			temp /= 256;
		}

		ptrdiff_t i = text.lastIndexOf(' ');
		
		if (i == 0)
			return null;
		else if (i == -1)
			return text.idup;
		else
			return text[0 .. i].idup;
	}
}

///
alias EventType = EventSource;
