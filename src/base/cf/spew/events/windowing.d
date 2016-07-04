module cf.spew.events.windowing;
import cf.spew.events.defs;

enum Windowing_Events_Types {
	/// Prefix to determine if it is standard windowing types
	Prefix = EventType.from("w_"),
	///
	Window_Moved = EventType.from("w_moved"),
	Window_Resized = EventType.from("w_resize"),
	Window_Focused = EventType.from("w_focus"),
	Window_RequestClose = EventType.from("w_reqclo"),
	Window_CursorMoved = EventType.from("w_curmvd"),
	Window_CursorAction = EventType.from("w_curac"),
	Window_CursorActionEnd = EventType.from("w_/curac"),
	Window_CursorActionDo = EventType.from("w_!curac"),
	Window_CursorScroll = EventType.from("w_cursc"),
	Window_KeyDown = EventType.from("w_kdw"),
	Window_KeyUp = EventType.from("w_k/dw"),
	Window_KeyInput = EventType.from("w_ki"),

}

union Windowing_Events {
	struct {
		/// cursor moved + stopped moving + window moved + cursor action
		int newX, newY;
	}

	struct {
		union {
			struct {
				// cursor action

				/// 
				CursorEventAction cursorAction;
				///
				bool isDoubleClick;
			}

			struct {
				// scroll
				
				///
				int amount;
			}

		}

		///
		int atX, atY;
	}

	struct {
		// close
	}

	struct {
		// window size changed

		///
		uint newWidth, newHeight;
	}

	struct {
		// key down + up

		////
		dchar key;
		/// See_Also: KeyModifiers
		ushort keyModifiers;
		///
		SpecialKey keySpecial;
	}
}

///
enum CursorEventAction {
	/**
     * Triggered when the left mouse button is clicked when backed by a mouse.
     */
	Select,
	
	/**
     * Triggered when the right mouse button is clicked when backed by a mouse.
     */
	Alter,
	
	/**
     * Triggered when the middle mouse button is clicked when backed by a mouse.
     */
	ViewChange
}

///
enum KeyModifiers : ushort {
	///
	None = 0,
	
	///
	Control = 1 << 1,
	///
	LControl = Control | (1 << 2),
	///
	RControl = Control | (1 << 3),
	
	///
	Alt = 1 << 4,
	///
	LAlt = Alt | (1 << 5),
	///
	RAlt = Alt | (1 << 6),
	
	///
	Shift = 1 << 7,
	///
	LShift = Shift | (1 << 8),
	///
	RShift = Shift | (1 << 9),
	
	///
	Super = 1 << 10,
	///
	LSuper = Super | (1 << 11),
	///
	RSuper = Super | (1 << 12),
	
	///
	Capslock = 1 << 13,
	
	///
	Numlock = 1 << 14
}

///
enum SpecialKey {
	///
	None,
	
	///
	F1,
	///
	F2,
	///
	F3,
	///
	F4,
	///
	F5,
	///
	F6,
	///
	F7,
	///
	F8,
	///
	F9,
	///
	F10,
	///
	F11,
	///
	F12,
	
	///
	Escape,
	///
	Enter,
	///
	Backspace,
	///
	Tab,
	///
	PageUp,
	///
	PageDown,
	///
	End,
	///
	Home,
	///
	Insert,
	///
	Delete,
	///
	Pause,
	
	///
	LeftArrow, 
	///
	RightArrow,
	///
	UpArrow,
	///
	DownArrow,
	
	///
	ScrollLock
}

