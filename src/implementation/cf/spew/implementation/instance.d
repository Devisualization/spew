module cf.spew.implementation.instance;
import cf.spew.instance;
import cf.spew.ui.features;
import std.experimental.allocator : IAllocator, make, dispose, processAllocator, theAllocator;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGBA8;
import std.experimental.memory.managed;
import cf.spew.ui.rendering : vec2;

final class DefaultImplementation : Instance {
	import cf.spew.event_loop.defs : EventLoopSource, EventLoopConsumer;

	~this() {
		if (__Initialized) {
			allocator.dispose(_eventLoop);
			allocator.dispose(_userInterface);

			allocator.dispose(_mainEventSource_);
			allocator.dispose(_mainEventConsumer_);
		}
	}

	bool __Initialized;
	IAllocator allocator;
	Management_EventLoop _eventLoop;
	UIInstance _userInterface;

	@property {
		override Management_EventLoop eventLoop() {
			__guardCheck();
			return _eventLoop;
		}

		override Management_UserInterface userInterface() {
			__guardCheck();
			return _userInterface;
		}
	}

	// this can be safely inlined!
	pragma(inline, true)
	void __guardCheck() {
		if (!__Initialized)
			__handleGuardCheck();
	}

	private {
		EventLoopSource _mainEventSource_;
		EventLoopConsumer _mainEventConsumer_;
	}

	void __handleGuardCheck() {
		__Initialized = true;
		allocator = processAllocator;

		_eventLoop = allocator.make!EventLoopWrapper(allocator);

		version(Windows) {
			import cf.spew.event_loop.wells.winapi;
			import cf.spew.implementation.consumers;

			_userInterface = allocator.make!UIInstance_WinAPI(allocator);

			_mainEventSource_ = allocator.make!WinAPI_EventLoop_Source;
			_eventLoop.manager.addSources(_mainEventSource_);
			_mainEventConsumer_ = allocator.make!EventLoopConsumerImpl_WinAPI(this);
			_eventLoop.manager.addConsumers(_mainEventConsumer_);
		}
	}
}

final class EventLoopWrapper : Management_EventLoop {
	import cf.spew.event_loop.defs : IEventLoopManager;
	import cf.spew.implementation.manager;

	this(IAllocator allocator) {
		this.allocator = allocator;
		_manager = allocator.make!EventLoopManager_Impl;
	}

	~this() {
		allocator.dispose(_manager);
	}

	IAllocator allocator;
	IEventLoopManager _manager;

	bool isRunningOnMainThread() { return _manager.runningOnMainThread; }
	bool isRunning() { return _manager.runningOnMainThread || _manager.runningOnAuxillaryThreads; }
	void stopCurrentThread() { _manager.runningOnThreadFor; }
	void stopAllThreads() { _manager.stopAllThreads; }
	void execute() { _manager.execute; }

	@property IEventLoopManager manager() { return _manager; }
}

abstract class UIInstance : Management_UserInterface, Have_Notification {
	import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
	import std.experimental.allocator : IAllocator, processAllocator;
	import std.experimental.memory.managed;
	import std.experimental.containers.map;

	this(IAllocator allocator) {
		this.allocator = allocator;
		windowToIdMapper = Map!(size_t, IWindow)(allocator);
	}

	IAllocator allocator;
	/// ONLY use this if IWindow has events enabled!
	Map!(size_t, IWindow) windowToIdMapper = void;

	// notifications

	IAllocator taskbarCustomIconAllocator;
	ImageStorage!RGBA8 taskbarCustomIcon;

	//

	managed!IWindowCreator createWindow(IAllocator alloc = processAllocator()) { assert(0); }

	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = processAllocator())
	{ return cast(managed!IRenderPointCreator)createWindow(alloc); }

	IRenderPoint createARenderPoint(IAllocator alloc = processAllocator())
	{ return createAWindow(alloc); }

	IWindow createAWindow(IAllocator alloc = processAllocator()) {
		import cf.spew.ui.context.features.vram;

		auto creator = createWindow(alloc);
		creator.size = vec2!ushort(cast(short)800, cast(short)600);
		creator.assignVRamContext;
		return creator.createWindow();
	}
	
	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator()) { assert(0); }
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator()) { assert(0); }
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator()) { assert(0); }
	}

	// notifications

	Feature_Notification __getFeatureNotification() { return null; }
}

version(Windows) {
	final class UIInstance_WinAPI : UIInstance, Feature_Notification {
		import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_WinAPI;
		import cf.spew.implementation.windowing.misc;
		import std.experimental.graphic.image.storage.base : ImageStorageHorizontal;
		import std.experimental.graphic.image.interfaces : imageObjectFrom;
		import std.typecons : tuple;
		import winapi = core.sys.windows.windows;
		import winapishell = core.sys.windows.shellapi;
		import core.sys.windows.w32api : _WIN32_IE;

		IWindow taskbarIconWindow;
		winapi.NOTIFYICONDATAW taskbarIconNID;

		this(IAllocator allocator) {
			super(allocator);
		}

		~this() {
			allocator.dispose(taskbarIconWindow);
		}

		override {
			managed!IWindowCreator createWindow(IAllocator alloc = processAllocator()) {
				return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(), tuple(this, alloc), alloc);
			}

			@property {
				managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator()) {
					GetPrimaryDisplay_WinAPI ctx = GetPrimaryDisplay_WinAPI(alloc, this);
					ctx.call;

					if (ctx.display is null)
						return managed!IDisplay.init;
					else
						return managed!IDisplay(ctx.display, managers(), Ownership.Secondary, alloc);
				}

				managed!(IDisplay[]) displays(IAllocator alloc = processAllocator()) {
					GetDisplays_WinAPI ctx = GetDisplays_WinAPI(alloc, this);
					ctx.call;
					return managed!(IDisplay[])(ctx.displays, managers(), Ownership.Secondary, alloc);
				}

				managed!(IWindow[]) windows(IAllocator alloc = processAllocator()) {
					GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc, this);
					ctx.call;
					return managed!(IWindow[])(ctx.windows, managers(), Ownership.Secondary, alloc);
				}
			}

			// notifications
			static if (_WIN32_IE >= 0x500) {
				Feature_Notification __getFeatureNotification() { return this; }

				@property {
					ImageStorage!RGBA8 getNotificationIcon(IAllocator alloc=theAllocator) {
						return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(taskbarCustomIcon, alloc);
					}

					void setNotificationIcon(ImageStorage!RGBA8 icon, IAllocator alloc=theAllocator) {
						if (icon is null) {
							winapi.Shell_NotifyIconW(winapi.NIM_DELETE, &taskbarIconNID);
							taskbarIconNID = winapi.NOTIFYICONDATAW.init;
						} else {
							bool toAdd = taskbarIconNID is winapi.NOTIFYICONDATAW.init;
							
							if (taskbarIconWindow is null) {
								taskbarIconWindow = createAWindow(allocator);
							}

							taskbarIconNID.cbSize = winapi.NOTIFYICONDATAW.sizeof;
							taskbarIconNID.uVersion = NOTIFYICON_VERSION_4;
							taskbarIconNID.uFlags = winapi.NIF_ICON | winapi.NIF_STATE;
							taskbarIconNID.hWnd = *cast(winapi.HWND*)taskbarIconWindow.__handle;
							
							winapi.HDC hFrom = winapi.GetDC(null);
							winapi.HDC hMemoryDC = winapi.CreateCompatibleDC(hFrom);
							
							scope(exit) {
								winapi.DeleteDC(hMemoryDC);
								winapi.ReleaseDC(null, hFrom);
							}
							
							if (taskbarIconNID.hIcon !is null) {
								winapi.DeleteObject(taskbarIconNID.hIcon);
								taskbarCustomIconAllocator.dispose(taskbarCustomIcon);
							}
							
							taskbarCustomIconAllocator = alloc;
							taskbarCustomIcon = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(icon, alloc);
							
							taskbarIconNID.hIcon = imageToIcon_WinAPI(icon, hMemoryDC, alloc);
							
							if (toAdd) {
								winapi.Shell_NotifyIconW(winapi.NIM_ADD, &taskbarIconNID);
							} else {
								winapi.Shell_NotifyIconW(winapi.NIM_MODIFY, &taskbarIconNID);
							}
							
							winapi.Shell_NotifyIconW(winapishell.NIM_SETVERSION, &taskbarIconNID);
						}
					}
				}
				
				void notify(ImageStorage!RGBA8 icon, dstring title, dstring text, IAllocator alloc=theAllocator) {
					import std.utf : byUTF;
					if (taskbarIconWindow is null)
						taskbarIconWindow = createAWindow(allocator);
					
					winapi.NOTIFYICONDATAW nid;
					nid.cbSize = winapi.NOTIFYICONDATAW.sizeof;
					nid.uVersion = NOTIFYICON_VERSION_4;
					nid.uFlags = winapi.NIF_ICON | NIF_SHOWTIP | winapi.NIF_INFO | winapi.NIF_STATE | NIF_REALTIME;
					nid.uID = 1;
					nid.hWnd = *cast(winapi.HWND*)taskbarIconWindow.__handle;
					
					size_t i;
					foreach(c; byUTF!wchar(title)) {
						if (i >= nid.szInfoTitle.length - 1) {
							nid.szInfoTitle[i] = cast(wchar)0;
							break;
						} else
							nid.szInfoTitle[i] = c;
						
						i++;
						if (i == title.length)
							nid.szInfoTitle[i] = cast(wchar)0;
					}
					
					i = 0;
					foreach(c; byUTF!wchar(text)) {
						if (i >= nid.szInfo.length - 1) {
							nid.szInfo[i] = cast(wchar)0;
							break;
						} else
							nid.szInfo[i] = c;
						
						i++;
						if (i == text.length)
							nid.szInfo[i] = cast(wchar)0;
					}
					
					winapi.HDC hFrom = winapi.GetDC(null);
					winapi.HDC hMemoryDC = winapi.CreateCompatibleDC(hFrom);
					
					scope(exit) {
						winapi.DeleteDC(hMemoryDC);
						winapi.ReleaseDC(null, hFrom);
					}
					
					nid.hIcon = imageToIcon_WinAPI(icon, hMemoryDC, alloc);
					
					winapi.Shell_NotifyIconW(winapi.NIM_ADD, &nid);
					winapi.Shell_NotifyIconW(winapi.NIM_SETVERSION, &nid);
					
					winapi.Shell_NotifyIconW(winapi.NIM_DELETE, &nid);
					winapi.DeleteObject(nid.hIcon);
				}

				void clearNotifications() {}
			} else {
				// not available.

				pragma(msg, "Notifications are not supported. To enable them pass version IE5 or greater (see core.sys.windows.w32api).");

				@property {
					ImageStorage!RGBA8 getNotificationIcon(IAllocator alloc=theAllocator) { assert(0); }
					void setNotificationIcon(ImageStorage!RGBA8, IAllocator alloc=theAllocator) { assert(0); }
				}
				
				void notify(ImageStorage!RGBA8, dstring, dstring, IAllocator alloc=theAllocator) { assert(0); }
				void clearNotifications() { assert(0); }
			}
		}
	}
}