module cf.spew.implementation.consumers;
public import cf.spew.ui;
public import cf.spew.platform;
public import cf.spew.event_loop;
public import cf.spew.events;
public import std.experimental.graphic.image : ImageStorage;
public import std.experimental.graphic.color : RGB8, RGBA8;
public import std.experimental.containers.list;
public import std.experimental.containers.map;
public import std.experimental.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
public import std.experimental.memory.managed;


abstract class EventLoopConsumerImpl : EventLoopConsumer {
	import cf.spew.events.windowing;
	//import cf.spew.implementation.windowing.window;
	import cf.spew.implementation.instance;
	import std.typecons : Nullable;

	DefaultImplementation instance;
	UIInstance uiInstance;
	
	this(DefaultImplementation instance) {
		this.instance = instance;
		this.uiInstance = cast(UIInstance)instance.ui;
	}
	
	bool processEvent(ref Event event) {
		/+IWindow window = uiInstance.windowToIdMapper[event.wellData1Value];
		
		if (window is null) {
			
		} else if (WindowImpl w = cast(WindowImpl)window) {
			switch(event.type) {
				case Windowing_Events_Types.Window_Moved:
					w.onMoveDel(event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
					return true;
				case Windowing_Events_Types.Window_Resized:
					w.onSizeChangeDel(event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
					return true;
				case Windowing_Events_Types.Window_KeyInput:
					w.onKeyEntryDel(event.windowing.keyInput.key, event.windowing.keyInput.special, event.windowing.keyInput.modifiers);
					return true;
				case Windowing_Events_Types.Window_CursorScroll:
					w.onScrollDel(event.windowing.scroll.amount);
					return true;
				case Windowing_Events_Types.Window_CursorMoved:
					w.onCursorMoveDel(event.windowing.cursorMoved.newX, event.windowing.cursorMoved.newY);
					return true;
				case Windowing_Events_Types.Window_CursorAction:
					w.onCursorActionDel(event.windowing.cursorAction.action);
					return true;
				case Windowing_Events_Types.Window_CursorActionEnd:
					w.onCursorActionEndDel(event.windowing.cursorAction.action);
					return true;
					
				case Windowing_Events_Types.Window_CursorActionDo:
				case Windowing_Events_Types.Window_Focused:
				case Windowing_Events_Types.Window_KeyDown:
				case Windowing_Events_Types.Window_KeyUp:
				default:
					return false;
			}
		}+/
		
		return false;
	}
	
	@property {
		Nullable!EventSource pairOnlyWithSource() { return Nullable!EventSource(); }
		
		EventType pairOnlyWithEvents() { return EventType.all; }
		
		byte priority() { return byte.max / 2; }
		
		string description() { return "Default implementation consumer for Windowing."; }
	}
}

version(Windows) {
	public import winapi = core.sys.windows.windows;

	final class EventLoopConsumerImpl_WinAPI : EventLoopConsumerImpl {
		import cf.spew.implementation.instance;
		//import cf.spew.implementation.windowing.window;
		import cf.spew.events.windowing;
		import cf.spew.events.winapi;
		
		this(DefaultImplementation instance) {
			super(instance);
		}
		
		override bool processEvent(ref Event event) {
			/+
			IWindow window = platform.windowToIdMapper[event.wellData1Value];

			if (window is null) {

			} else if (WindowImpl_WinAPI w = cast(WindowImpl_WinAPI)window) {
				WindowImpl w2 = cast(WindowImpl)w;
				switch(event.type) {
					case Windowing_Events_Types.Window_Resized:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						w2.onSizeChangeDel(event.windowing.windowResized.newWidth, event.windowing.windowResized.newHeight);
						return true;
					case Windowing_Events_Types.Window_Moved:
						winapi.InvalidateRgn(event.wellData1Ptr, null, 0);
						w2.onMoveDel(event.windowing.windowMoved.newX, event.windowing.windowMoved.newY);
						return true;

					case WinAPI_Events_Types.Window_Create:
						return false;
					case WinAPI_Events_Types.Window_Destroy:
						return false;
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
						return false;
					case WinAPI_Events_Types.Window_SystemColorsChanged:
						return false;
					case WinAPI_Events_Types.Window_DevModeChanged:
						return false;
					case WinAPI_Events_Types.Window_SetCursor:
						return false;
					case WinAPI_Events_Types.Window_EnterSizeMove:
						return false;
					case WinAPI_Events_Types.Window_ExitSizeMove:
						return false;
					case WinAPI_Events_Types.Window_RequestClose:
						return false;

					default:
						break;
				}
			}

			if (super.processEvent(event))
				return true;
			else
				return false;+/
			return super.processEvent(event);
		}

		@property {
			bool onMainThread() { return true; }
			bool onAdditionalThreads() { return true; }
		}
	}
}