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
union EventSource {
	///
	long value;
	char[8] text_;
	alias value this;

	/**
	 * 
	 */
	static EventSource from(const char[] from...)
	in {
		assert(from.length > 0);
		assert(from.length <= 8);
	} body {
		ubyte[8] rstr = cast(ubyte)' ';
		rstr[0 .. from.length] = cast(ubyte[])from[];
		
		return EventSource(rstr[0]  |
			(rstr[1] << (1 * 8)) |
			(rstr[2] << (2 * 8)) |
			(rstr[3] << (3 * 8)) |
			(cast(long)rstr[4] << (4 * 8)) |
			(cast(long)rstr[5] << (5 * 8)) |
			(cast(long)rstr[6] << (6 * 8)) |
			(cast(long)rstr[7] << (7 * 8)));
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

	bool opEquals(EventSource other) nothrow {
		import std.string : indexOf;
		
		ptrdiff_t i = text_.indexOf(' ');
		ptrdiff_t j = other.text_.indexOf(' ');
		
		if ((i < j || j < 0) && i >= 0) {
			// this == other
			return text_[0 .. i] == other.text_[0 .. i];
		} else
			return value == other.value;
	}
}

///
alias EventType = EventSource;
