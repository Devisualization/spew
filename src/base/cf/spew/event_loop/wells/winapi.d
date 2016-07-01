module cf.spew.event_loop.wells.winapi;
version(Windows):

import cf.spew.event_loop.defs;
import cf.spew.event_loop.known_implementations;
import cf.spew.events.defs;
import cf.spew.events.winapi;
import std.experimental.allocator : IAllocator, make;
import core.time : Duration;

final class WinAPI_EventLoop_Source : EventLoopSource {
	@property {
		bool onMainThread() { return true; }
		bool onAdditionalThreads() { return true; }

		EventSource identifier() { return EventSources.WinAPI; }
	}

	EventLoopSourceRetriever nextEventGenerator(IAllocator alloc) {
		return alloc.make!WinAPI_EventLoop_SourceRetriever;
	}
}


final class WinAPI_EventLoop_SourceRetriever : EventLoopSourceRetriever {
	private {
		import core.sys.windows.windows : DWORD, MSG, INFINITE;

		DWORD msTimeout = INFINITE;
		MSG msg;
		bool needToWait;
	}

	bool nextEvent(ref Event event) {
		import core.sys.windows.windows : MsgWaitForMultipleObjectsEx,
			QS_ALLINPUT, WAIT_TIMEOUT,
			MWMO_ALERTABLE, MWMO_INPUTAVAILABLE,
			PeekMessageW, PM_REMOVE,
			TranslateMessage, DispatchMessageW;

		if (needToWait) {
			MsgWaitForMultipleObjectsEx(
				cast(DWORD)0, null,
				msTimeout, QS_ALLINPUT,
				// MWMO_ALERTABLE: Wakes up to execute overlapped hEvent (i/o completion)
				// MWMO_INPUTAVAILABLE: Processes key/mouse input to avoid window ghosting
				MWMO_ALERTABLE | MWMO_INPUTAVAILABLE);
			needToWait = false;
		}

		for (;;) {
			if (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) == 0) {
				needToWait = true;
				return false;
			} else {
				if (msg.hwnd !is null && shouldTranslate)
					TranslateMessage(&msg);

				if (false/+ msgContextKnown(msg) +/) {

					// TODO: translate windowing messages
					// TODO: translate threading messages
					// TODO: translate timer messages
					// TODO: 

					event.source = EventSources.WinAPI;
					event.type = WinAPI_Events_Types.Unknown;
					event.winapi.raw = msg;

					return true;
				} else {
					DispatchMessageW(&msg);
					continue;
				}
			}
		}
	}

	void handledEvent(ref Event event) {}

	void unhandledEvent(ref Event event) {
		import core.sys.windows.windows : DefWindowProc;

		// only valid for window based events
		if (msg.hwnd !is null/+ && msgContextKnown(msg) +/)
			DefWindowProc(msg.hwnd, msg.message, msg.wParam, msg.lParam);
	}

	void hintTimeout(Duration timeout) {
		msTimeout = cast(DWORD)timeout.total!"msecs";

		if (msTimeout == 0)
			msTimeout = INFINITE;
	}

	bool shouldTranslate() {
		import core.sys.windows.windows : LOWORD, HIWORD,
			WM_SYSKEYDOWN, WM_SYSKEYUP, WM_KEYDOWN, WM_KEYUP, WM_CHAR,
			VK_NUMPAD0, VK_NUMPAD9, VK_ADD, VK_SUBTRACT, VK_MULTIPLY,
			VK_DIVIDE, VK_DECIMAL, VK_OEM_2, VK_OEM_PERIOD, VK_OEM_COMMA;
		
		auto id = LOWORD(msg.message);
		
		switch(id) {
			case WM_SYSKEYDOWN: case WM_SYSKEYUP:
			case WM_KEYDOWN: case WM_KEYUP:
			case WM_CHAR:
				break;
			default:
				return false;
		}
		
		switch(msg.wParam) {
			case VK_NUMPAD0: .. case VK_NUMPAD9:
				bool haveAlt = (msg.lParam & (1 << 29)) == 1 << 29;
				return haveAlt;
				
			case VK_ADD: case VK_SUBTRACT:
			case VK_MULTIPLY: case VK_DIVIDE:
			case VK_DECIMAL:
			case VK_OEM_2:
			case VK_OEM_PERIOD:
			case VK_OEM_COMMA:
				return false;
			default:
				return true;
		}
	}
}