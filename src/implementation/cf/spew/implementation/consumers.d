/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.consumers;
public import cf.spew.ui;
public import cf.spew.miscellaneous.timer;
public import cf.spew.event_loop;
public import cf.spew.events;
public import devisualization.image : ImageStorage;
public import std.experimental.color : RGB8, RGBA8;
public import std.experimental.containers.list;
public import std.experimental.containers.map;
public import std.experimental.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
public import devisualization.util.core.memory.managed;

abstract class EventLoopConsumerImpl : EventLoopConsumer {
	import cf.spew.events.windowing;
	import cf.spew.implementation.windowing.window;
	import cf.spew.implementation.instance;
	import std.typecons : Nullable;

	shared(DefaultImplementation) instance;
	shared(UIInstance) uiInstance;
	
	this(shared(DefaultImplementation) instance) shared {
		this.instance = instance;
		this.uiInstance = cast(shared(UIInstance))instance.ui;
	}
	
	bool processEvent(ref Event event) shared {
		// umm shouldn't we check that you know this is a windowing event?
		IWindow window = cast()uiInstance.windowToIdMapper[event.wellData1Value];
		
		if (window is null) {
		} else if (WindowImpl w = cast(WindowImpl)window) {
			switch(event.type) {
				case Windowing_Events_Types.Window_Moved:
					tryFunc(w.onMoveDel, event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
					return true;
				case Windowing_Events_Types.Window_Resized:
					tryFunc(w.onSizeChangeDel, event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
					return true;
				case Windowing_Events_Types.Window_CursorScroll:
					tryFunc(w.onScrollDel, event.windowing.scroll.amount / 120);
					return true;
				case Windowing_Events_Types.Window_CursorMoved:
					tryFunc(w.onCursorMoveDel, event.windowing.cursorMoved.newX, event.windowing.cursorMoved.newY);
					return true;
				case Windowing_Events_Types.Window_CursorAction:
					tryFunc(w.onCursorActionDel, event.windowing.cursorAction.action);
					return true;
				case Windowing_Events_Types.Window_CursorActionEnd:
					tryFunc(w.onCursorActionEndDel, event.windowing.cursorAction.action);
					return true;

				case Windowing_Events_Types.Window_KeyInput:
				case Windowing_Events_Types.Window_KeyUp:
					tryFunc(w.onKeyEntryDel, event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
					return true;

				case Windowing_Events_Types.Window_CursorActionDo:
				case Windowing_Events_Types.Window_KeyDown:
				default:
					return false;
			}
		}
		
		return false;
	}
	
	@property {
		Nullable!EventSource pairOnlyWithSource() shared { return Nullable!EventSource(); }
		
		EventType pairOnlyWithEvents() shared { return EventType.all; }
		
		byte priority() shared { return byte.max / 2; }
		
		string description() shared { return "Default implementation consumer for Windowing."; }
	}
}

private {
	import std.traits : ReturnType;

	void tryFunc(T, U...)(T func, U args) if (is(ReturnType!T == void)) {
		if (func !is null) {
			try {
				func(args);
			} catch(Exception e) {
			}
		}
	}

	J tryFunc(T, J=ReturnType!T, U...)(T func, J default_, U args) if (!is(ReturnType!T == void)) {
		if (func !is null) {
			try {
				return func(args);
			} catch(Exception e) {}
		}
		
		return default_;
	}
}

version(Windows) {
	public import winapi = core.sys.windows.windows;

	final class EventLoopConsumerImpl_WinAPI : EventLoopConsumerImpl {
		import cf.spew.implementation.instance;
		import cf.spew.implementation.windowing.window;
		import cf.spew.implementation.misc.timer;
		import cf.spew.events.windowing;
		import cf.spew.events.winapi;
		
		this(shared(DefaultImplementation) instance) shared {
			super(instance);
		}
		
		override bool processEvent(ref Event event) shared {
			IWindow window = cast()uiInstance.windowToIdMapper[event.wellData1Value];

			if (window is null) {
				ITimer timer = cast()this.instance._miscInstance.timerToIdMapper[event.wellData1Value];

				if (timer is null) {
				} else {
					switch(event.type) {
						case Windowing_Events_Types.Window_RequestClose:
							timer.stop();
							return true;

						case WinAPI_Events_Types.Window_Timer:
							if (TimerImpl timer2 = cast(TimerImpl)timer) {
								tryFunc(timer2.onEventDel, timer);
							}
							return true;
						default:
							return false;
					}
				}
			} else if (WindowImpl_WinAPI w = cast(WindowImpl_WinAPI)window) {
				WindowImpl w2 = cast(WindowImpl)w;

				switch(event.type) {
					case Windowing_Events_Types.Window_Resized:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						tryFunc(w2.onSizeChangeDel, event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
						return true;
					case Windowing_Events_Types.Window_Moved:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						tryFunc(w2.onMoveDel, event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
						return true;
					case Windowing_Events_Types.Window_Focused:
						if (winapi.LOWORD(event.wellData2Value) == 0) {
						} else {
							if (w.oldCursorClipArea != winapi.RECT.init)
								w.lockCursorToWindow;
						}
						return true;

					case WinAPI_Events_Types.Window_Quit:
						return false;
					case WinAPI_Events_Types.Window_GainedKeyboardFocus:
						return false;
					case WinAPI_Events_Types.Window_LostKeyboardFocus:
						return false;
					case WinAPI_Events_Types.Window_Enable:
						return false;
					case WinAPI_Events_Types.Window_Disable:
						return false;
					case WinAPI_Events_Types.Window_SetRedraw:
						return false;
					
					case WinAPI_Events_Types.Window_Paint:
						return handlePaint(event, w, w2);
					case WinAPI_Events_Types.Window_SystemColorsChanged:
						return false;
					case WinAPI_Events_Types.Window_DevModeChanged:
						return false;
					case WinAPI_Events_Types.Window_SetCursor:
						if (winapi.LOWORD(event.wellData2Value) == winapi.HTCLIENT && w.cursorStyle != WindowCursorStyle.Underterminate) {
							winapi.SetCursor(w.hCursor);
							return true;
						}
						return false;
					case WinAPI_Events_Types.Window_EnterSizeMove:
						return false;
					case WinAPI_Events_Types.Window_ExitSizeMove:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						return true;
					case Windowing_Events_Types.Window_RequestClose:
						if (tryFunc(w2.onRequestCloseDel, true)) {
							winapi.DestroyWindow(event.wellData1Ptr);
						}
						return true;
					case WinAPI_Events_Types.Menu_Click:
						tryFunc(w.menuCallbacks[event.wellData2Value], w.menuItemsIds[event.wellData2Value]);
						return true;

					case WinAPI_Events_Types.Window_DragAndDrop:
						import std.utf : byChar, codeLength;
						import core.sys.windows.windows;

						HDROP hdrop = cast(HDROP)event.wellData2Ptr;
						POINT point;
						DragQueryPoint(hdrop, &point);

						auto alloc = w2.allocator();
						wchar[] buffer1 = alloc.makeArray!wchar(256);
						char[] buffer2 = alloc.makeArray!char(256);

						size_t count, len1, len2;
						while((len1 = DragQueryFileW(hdrop, cast(uint)count, null, 0)) != 0) {
							if (buffer1.length < len1) {
								alloc.expandArray(buffer1, len1-buffer1.length);
							}

							DragQueryFileW(hdrop, cast(uint)count++, buffer1.ptr, cast(uint)buffer1.length);

							len2 = codeLength!char(buffer1[0 .. len1]);
							if (buffer2.length < len2) {
								alloc.expandArray(buffer2, len2-buffer2.length);
							}

							size_t offset;
							foreach(c; buffer1[0 .. len1].byChar) {
								buffer2[offset++] = c;
							}

							if (w2.onFileDropDel !is null) {
								try {
									w2.onFileDropDel(cast(string)buffer2[0 .. len2], point.x, point.y);
								} catch(Exception e) {}
							}
						}

						alloc.dispose(buffer1);
						alloc.dispose(buffer2);

						DragFinish(hdrop);
						return true;

					case Windowing_Events_Types.Window_KeyUp:
						tryFunc(w2.onKeyEntryDel, event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
						tryFunc(w2.onKeyReleaseDel, event.windowing.keyUp.key, event.windowing.keyUp.special, event.windowing.keyUp.modifiers);
						return true;
					case Windowing_Events_Types.Window_KeyDown:
						tryFunc(w2.onKeyPressDel, event.windowing.keyDown.key, event.windowing.keyDown.special, event.windowing.keyDown.modifiers);
						return true;

					default:
						if (event.type == WinAPI_Events_Types.Raw) {
							if (event.winapi.raw.message == winapi.WM_ERASEBKGND) {
								return handlePaint(event, w, w2);
							}
						}
						break;
				}
			}

			if (super.processEvent(event))
				return true;
			else
				return false;
		}

		@property {
			override Nullable!EventSource pairOnlyWithSource() shared { return Nullable!EventSource(EventSources.WinAPI); }
			bool onMainThread() shared { return true; }
			bool onAdditionalThreads() shared { return true; }
		}

		bool handlePaint(ref Event event, WindowImpl_WinAPI w, WindowImpl w2) shared {
			winapi.ValidateRgn(event.wellData1Ptr, null);

			if (w2.context_ is null) {
				winapi.PAINTSTRUCT ps;
				winapi.HDC hdc = winapi.BeginPaint(event.wellData1Ptr, &ps);
				winapi.FillRect(hdc, &ps.rcPaint, cast(winapi.HBRUSH) (winapi.COLOR_WINDOW+1));
				winapi.EndPaint(event.wellData1Ptr, &ps);
			} else if (w2.onDrawDel is null) {
				w2.context.activate;
				w2.context.deactivate;
			} else {
				tryFunc(w2.onDrawDel);
			}

			return true;
		}
	}
}