/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.events.windowing;
import cf.spew.events.defs;

///
enum Windowing_Events_Types {
	/// Prefix to determine if it is standard windowing types
	Prefix = EventType.from("w_"),
	///
	Window_Moved = EventType.from("w_moved"),
	///
	Window_Resized = EventType.from("w_resize"),
	///
	Window_CursorMoved = EventType.from("w_curmvd"),
	///
	Window_CursorAction = EventType.from("w_curac"),
	///
	Window_CursorActionEnd = EventType.from("w_/curac"),
	///
	Window_CursorActionDo = EventType.from("w_!curac"),
	///
	Window_CursorScroll = EventType.from("w_cursc"),
	///
	Window_KeyDown = EventType.from("w_kdw"),
	///
	Window_KeyUp = EventType.from("w_k/dw"),
	///
	Window_KeyInput = EventType.from("w_ki"),
	///
	Window_RequestClose = EventType.from("w_reqclo"),
    ///
    Window_Show = EventType.from("w_show"),
    ///
    Window_Hide = EventType.from("w_hide"),

}

///
union Windowing_Events {
	///
	Windowing_Event_Cursor_Action cursorAction;
	/// 
	Windowing_Event_Moved cursorMoved;
	///
	Windowing_Event_Scroll scroll;

	///
	Windowing_Event_Resized windowResized;
	/// 
	Windowing_Event_Moved windowMoved;
	/// 
	Windowing_Event_Moved stoppedMoving;

	///
	Windowing_Event_Key keyDown;
	///
	Windowing_Event_Key keyUp;
	/// singular event aka press
	Windowing_Event_Key keyInput;
}

///
struct Windowing_Event_Moved {
	///
	int newX, newY;
}

///
struct Windowing_Event_Cursor_Action {
	///
	int x, y;
	///
	CursorEventAction action;
	///
	bool isDoubleClick;
}

///
struct Windowing_Event_Scroll {
	///
	int x, y;
	///
	int amount;
}

///
struct Windowing_Event_Resized {
	///
	uint newWidth, newHeight;
}

///
struct Windowing_Event_Key {
	///
	dchar key;
	/// See_Also: KeyModifiers
	ushort modifiers;
	///
	SpecialKey special;
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
	F13,
	///
	F14,
	///
	F15,
	///
	F16,
	///
	F17,
	///
	F18,
	///
	F19,
	///
	F20,
	///
	F21,
	///
	F22,
	///
	F23,
	///
	F24,

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

