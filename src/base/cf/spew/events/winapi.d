module cf.spew.events.winapi;
version(Windows):

import cf.spew.events.defs;
import std.experimental.memory.managed;
import core.sys.windows.windows : MSG, CREATESTRUCT, HWND;

enum WinAPI_Events_Types {
	Prefix = EventType.from("|w"),
	Unknown = EventType.from("|wunknwn"),
	Raw = EventType.from("|wraw"),
	Window_Create = EventType.from("|wcreate"),
	Window_Destroy = EventType.from("|wdestry"),
	Window_Quit = EventType.from("|wquit"),
	Window_GainedKeyboardFocus = EventType.from("|wkfoc"),
	Window_LostKeyboardFocus = EventType.from("|w/kfoc"),
	Window_Enable = EventType.from("|weble"),
	Window_Disable = EventType.from("|w/eble"),
	Window_SetRedraw = EventType.from("|wsrd"),
	Window_Paint = EventType.from("|wpaint"),
	Window_SystemColorsChanged = EventType.from("|wscolch"),
	Window_DevModeChanged = EventType.from("|wdevmc"),
	Window_SetCursor = EventType.from("|wsetcur"),
	Window_EnterSizeMove = EventType.from("|wszmv"),
	Window_ExitSizeMove = EventType.from("|w/szmv"),
}

union WinAPI_Events {
	// WM_ERASEBKGND
	MSG raw;

	// WM_CREATE
	CREATESTRUCT window_create;

	// WM_SETFOCUS
	HWND lostFocusWindow;
	// WM_KILLFOCUS
	HWND gainedFocusWindow;

	// WM_SETREDRAW
	bool redrawState;
}