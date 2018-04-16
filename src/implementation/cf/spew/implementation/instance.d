/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.instance;
import cf.spew.instance;
import cf.spew.ui.features;
import stdx.allocator : IAllocator, ISharedAllocator, make, dispose, processAllocator, theAllocator, makeArray;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import devisualization.util.core.memory.managed;
import cf.spew.ui.rendering : vec2;
import std.socket :  InternetAddress, Internet6Address;

final class DefaultImplementation : Instance {
	import cf.spew.event_loop.defs : EventLoopSource, EventLoopConsumer;
	import core.thread : ThreadID, Thread;

	~this() {
		if (__Initialized) {
			if (_eventLoop !is null) allocator.dispose(_eventLoop);
			if (_userInterface !is null) allocator.dispose(_userInterface);
			if (_streamInstance !is null) allocator.dispose(_streamInstance);

            if (_secondaryEventSource_ !is null) allocator.dispose(_secondaryEventSource_);
			if (_mainEventSource_ !is null) allocator.dispose(_mainEventSource_);
			if (_mainEventConsumer_ !is null) allocator.dispose(_mainEventConsumer_);
		}
	}

	bool __Initialized;
	shared(ISharedAllocator) allocator;
	shared(Management_EventLoop) _eventLoop;
	shared(UIInstance) _userInterface;
	shared(StreamsInstance) _streamInstance;
	shared(Miscellaneous_Instance) _miscInstance;

	@property {
		override shared(Management_EventLoop) eventLoop() shared {
			__guardCheck();
			return _eventLoop;
		}

		override shared(Management_UserInterface) userInterface() shared {
			__guardCheck();
			return _userInterface;
		}

		override shared(Management_Streams) streams() shared {
			__guardCheck();
			return _streamInstance;
		}

		override shared(Management_Miscellaneous) misc() shared {
			__guardCheck();
			return _miscInstance;
		}
	}

	// this can be safely inlined!
	pragma(inline, true)
	void __guardCheck() shared {
		if (!__Initialized)
			__handleGuardCheck();
	}

	private {
		shared(EventLoopSource) _mainEventSource_, _secondaryEventSource_;
		shared(EventLoopConsumer) _mainEventConsumer_;
	}

	void __handleGuardCheck() shared {
		__Initialized = true;
		allocator = processAllocator();

		_eventLoop = allocator.make!(shared(EventLoopWrapper))(allocator);
		_miscInstance = allocator.make!(shared(Miscellaneous_Instance))(allocator);

		// LibUV stuff for streams support
		version(all) {
			import cf.spew.event_loop.wells.libuv;

			_streamInstance = allocator.make!(shared(StreamsInstance_LibUV))(allocator);
			_eventLoop.manager.addSources(LibUVEventLoopSource.instance);
		}

		version(Windows) {
			import cf.spew.event_loop.wells.winapi;
			import cf.spew.implementation.consumers;
			import core.sys.windows.ole2 : OleInitialize;

			OleInitialize(null);
			_userInterface = allocator.make!(shared(UIInstance_WinAPI))(allocator);

			_mainEventSource_ = allocator.make!(shared(WinAPI_EventLoop_Source));
			_eventLoop.manager.addSources(_mainEventSource_);
			_mainEventConsumer_ = allocator.make!(shared(EventLoopConsumerImpl_WinAPI))(this);
			_eventLoop.manager.addConsumers(_mainEventConsumer_);
		}

		if (_userInterface is null) {
			if (__checkForX11()) {
				import devisualization.bindings.x11;
                import devisualization.bindings.libnotify.loader;
				import cf.spew.event_loop.wells.x11;
                import cf.spew.event_loop.wells.glib;

				x11.XkbSetDetectableAutoRepeat(x11Display(), true, null);

                if (libnotifyLoader is LibNotifyLoader.init) {
                    libnotifyLoader = LibNotifyLoader(null);

                    if (libnotify.gdk_pixbuf_new_from_data !is null &&
                        libnotify.gdk_pixbuf_unref !is null &&
                        libnotify.gdk_pixbuf_scale_simple !is null) {

                        _secondaryEventSource_ = allocator.make!(shared(GlibEventLoopSource))(GlibEventLoopSource.Bindings(
                            libnotify.g_main_context_default, libnotify.g_main_context_iteration, libnotify.g_main_context_ref, libnotify.g_main_context_unref));
                        _eventLoop.manager.addSources(_secondaryEventSource_);
                        _userInterface = allocator.make!(shared(UIInstance_X11_Libnotify))(allocator);
                    }
                }

                if (_userInterface is null)
				    _userInterface = allocator.make!(shared(UIInstance_X11))(allocator);
				_eventLoop.manager.addSources(X11EventLoopSource.instance);
			}
		}
	}

	bool __checkForX11() shared {
		import devisualization.bindings.x11;
		import cf.spew.event_loop.wells.x11;
		return x11Display() !is null &&
			x11.XScreenNumberOfScreen !is null &&
			x11.XkbSetDetectableAutoRepeat !is null;
	}
}

final class EventLoopWrapper : Management_EventLoop {
	import cf.spew.event_loop.defs : IEventLoopManager;
	import cf.spew.implementation.manager;

	this(shared(ISharedAllocator) allocator) shared {
		this.allocator = allocator;
		_manager = allocator.make!(shared(EventLoopManager_Impl));
	}

	~this()  {
		allocator.dispose(_manager);
	}

	shared(ISharedAllocator) allocator;
	shared(IEventLoopManager) _manager;

	bool isRunningOnMainThread() shared  { return _manager.runningOnMainThread; }
	bool isRunning() shared  { return _manager.runningOnMainThread || _manager.runningOnAuxillaryThreads; }
	void stopCurrentThread() shared  { _manager.runningOnThreadFor; }
	void stopAllThreads() shared  { _manager.stopAllThreads; }
	void execute() shared  { _manager.execute; }

	@property shared(IEventLoopManager) manager() shared { return _manager; }
}

abstract class UIInstance : Management_UserInterface, Have_Notification, Have_Management_Clipboard {
	import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
	import stdx.allocator : IAllocator, processAllocator;
	import devisualization.util.core.memory.managed;
	import std.experimental.containers.map;

	this(shared(ISharedAllocator) allocator) shared {
		this.allocator = allocator;
		windowToIdMapper = SharedMap!(size_t, IWindow)(allocator);
	}

	shared(ISharedAllocator) allocator;
	/// ONLY use this if IWindow has events enabled!
	shared(SharedMap!(size_t, IWindow)) windowToIdMapper;

	// notifications

	shared(ISharedAllocator) taskbarCustomIconAllocator;
	shared(ImageStorage!RGBA8) taskbarCustomIcon;

	//

	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared { assert(0); }

	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) shared
	{ return cast(managed!IRenderPointCreator)createWindow(alloc); }

	managed!IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) shared
	{ return cast(managed!IRenderPoint)createAWindow(alloc); }

	managed!IWindow createAWindow(IAllocator alloc = theAllocator()) shared {
		import cf.spew.ui.context.features.vram;

		auto creator = createWindow(alloc);
		creator.size = vec2!ushort(cast(short)800, cast(short)600);
		creator.assignVRamContext;
		return creator.createWindow();
	}

	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared { assert(0); }

		managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared { assert(0); }

		managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared { assert(0); }
	}

	// notifications

	shared(Feature_Notification) __getFeatureNotification() shared { return null; }

	// clipboard

	shared(Feature_Management_Clipboard) __getFeatureClipboard() shared { return null; }
}

version(Windows) {
	final class UIInstance_WinAPI : UIInstance, Feature_Notification, Feature_Management_Clipboard {
		import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_WinAPI;
		import cf.spew.implementation.windowing.misc;
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObjectFrom;
		import std.typecons : tuple;
		import winapi = core.sys.windows.windows;
		import winapishell = core.sys.windows.shellapi;
		import core.sys.windows.w32api : _WIN32_IE;

		winapi.HWND taskbarIconWindow;
		winapi.NOTIFYICONDATAW taskbarIconNID;

		size_t maxClipboardSizeV = size_t.max;

		this(shared(ISharedAllocator) allocator) shared {
			super(allocator);
		}

		~this() {
			if (taskbarIconWindow)
				winapi.DestroyWindow(cast()taskbarIconWindow);
		}

		override {
			managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
				return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(), tuple(this, alloc), alloc);
			}

			@property {
				managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
					GetPrimaryDisplay_WinAPI ctx = GetPrimaryDisplay_WinAPI(alloc, this);
					ctx.call;

					if (ctx.display is null)
						return managed!IDisplay.init;
					else
						return managed!IDisplay(ctx.display, managers(ReferenceCountedManager()), alloc);
				}

				managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
					GetDisplays_WinAPI ctx = GetDisplays_WinAPI(alloc, this);
					ctx.call;
					return managed!(IDisplay[])(ctx.displays, managers(ReferenceCountedManager()), alloc);
				}

				managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
					GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc, this);
					ctx.call;
					return managed!(IWindow[])(ctx.windows, managers(ReferenceCountedManager()), alloc);
				}
			}

			// notifications
			static if (_WIN32_IE >= 0x500) {
				shared(Feature_Notification) __getFeatureNotification() shared { return this; }

				@property {
					shared(ImageStorage!RGBA8) getNotificationIcon(shared(ISharedAllocator) alloc) shared {
						return imageObjectFrom!(shared(ImageStorageHorizontal!RGBA8))(taskbarCustomIcon, alloc);
					}

					void setNotificationIcon(shared(ImageStorage!RGBA8) icon, shared(ISharedAllocator) alloc) shared {
						if (icon is null) {
							winapi.Shell_NotifyIconW(winapi.NIM_DELETE, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
							taskbarIconNID = winapi.NOTIFYICONDATAW.init;
						} else {
							bool toAdd = cast()taskbarIconNID is winapi.NOTIFYICONDATAW.init;

							if (taskbarIconWindow is null)
								taskbarIconWindow = cast(shared)winapi.CreateWindow(null, null, 0, 0, 0, 0, 0, null, null, null, null);

							taskbarIconNID.cbSize = winapi.NOTIFYICONDATAW.sizeof;
							taskbarIconNID.uVersion = NOTIFYICON_VERSION_4;
							taskbarIconNID.uFlags = winapi.NIF_ICON | winapi.NIF_STATE;
							taskbarIconNID.hWnd = cast()taskbarIconWindow;

							winapi.HDC hFrom = winapi.GetDC(null);
							winapi.HDC hMemoryDC = winapi.CreateCompatibleDC(hFrom);

							scope(exit) {
								winapi.DeleteDC(hMemoryDC);
								winapi.ReleaseDC(null, hFrom);
							}

							if (taskbarIconNID.hIcon !is null) {
								winapi.DeleteObject(cast(void*)taskbarIconNID.hIcon);
								taskbarCustomIconAllocator.dispose(taskbarCustomIcon);
							}

							taskbarCustomIconAllocator = alloc;
							taskbarCustomIcon = imageObjectFrom!(shared(ImageStorageHorizontal!RGBA8))(icon, alloc);

							taskbarIconNID.hIcon = cast(shared)imageToIcon_WinAPI(icon, hMemoryDC, alloc);

							if (toAdd) {
								winapi.Shell_NotifyIconW(winapi.NIM_ADD, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
							} else {
								winapi.Shell_NotifyIconW(winapi.NIM_MODIFY, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
							}

							winapi.Shell_NotifyIconW(winapishell.NIM_SETVERSION, cast(winapi.NOTIFYICONDATAW*)&taskbarIconNID);
						}
					}
				}

				void notify(shared(ImageStorage!RGBA8) icon, shared(dstring) title, shared(dstring) text, shared(ISharedAllocator) alloc) shared {
					import std.utf : byUTF;
					if (taskbarIconWindow is null)
						taskbarIconWindow = cast(shared)winapi.CreateWindow(null, null, 0, 0, 0, 0, 0, null, null, null, null);

					winapi.NOTIFYICONDATAW nid;
					nid.cbSize = winapi.NOTIFYICONDATAW.sizeof;
					nid.uVersion = NOTIFYICON_VERSION_4;
					nid.uFlags = winapi.NIF_ICON | NIF_SHOWTIP | winapi.NIF_INFO | winapi.NIF_STATE | NIF_REALTIME;
					nid.uID = 1;
					nid.hWnd = cast(winapi.HWND)taskbarIconWindow;

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

				void clearNotifications() shared {}
			} else {
				// not available.

				pragma(msg, "Notifications are not supported. To enable them pass version IE5 or greater (see core.sys.windows.w32api).");

				@property {
					shared(ImageStorage!RGBA8) getNotificationIcon(shared(ISharedAllocator) alloc) shared { assert(0); }
					void setNotificationIcon(shared(ImageStorage!RGBA8) icon, shared(ISharedAllocator) alloc) shared { assert(0); }
				}

				void notify(shared(ImageStorage!RGBA8) icon, shared(dstring) title, shared(dstring) text, shared(ISharedAllocator) alloc) shared { assert(0); }
				void clearNotifications() shared { assert(0); }
			}

			// clipboard

			shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
				return winapi.OpenClipboard(null) != 0 ? this : null;
			}

			@property {
				void maxClipboardDataSize(size_t amount) shared { maxClipboardSizeV = amount; }

				size_t maxClipboardDataSize() shared { return maxClipboardSizeV; }

				managed!string clipboardText(IAllocator alloc) shared {
					import std.utf : byChar, codeLength;
					char[] ret;

					winapi.HANDLE h = winapi.GetClipboardData(winapi.CF_UNICODETEXT);
					if (h !is null) {
						wchar* theData = cast(wchar*)winapi.GlobalLock(h);
						size_t theDataLength, realDataLength;
						while(theData[theDataLength++] != 0) {}
						wchar[] theData2 = theData[0 .. theDataLength-1];

						realDataLength = theData2.codeLength!char;
						ret = alloc.makeArray!char(realDataLength);
						size_t offset;
						foreach(c; theData2.byChar)
							ret[offset++] = c;

						winapi.GlobalUnlock(h);
					} else {
						h = winapi.GetClipboardData(winapi.CF_TEXT);

						if (h !is null) {
							char* theData = cast(char*)winapi.GlobalLock(h);
							size_t theDataLength;
							while(theData[theDataLength++] != 0) {}

							ret = alloc.makeArray!char(theDataLength-1);
							ret[] = theData[0 .. theDataLength];

							winapi.GlobalUnlock(h);
						}
					}

					winapi.CloseClipboard();

					if (ret !is null)
						return managed!string(cast(string)ret, managers(), alloc);
					else
						return managed!string.init;
				}

				void clipboardText(scope string text) shared {
					import std.utf : byWchar, codeLength;
					winapi.EmptyClipboard();

					size_t realLength = text.codeLength!char;
					winapi.HGLOBAL hglb = winapi.GlobalAlloc(winapi.GMEM_MOVEABLE, (realLength+1)*wchar.sizeof);

					if (hglb !is null) {
						wchar* wtext = cast(wchar*)winapi.GlobalLock(hglb);
						size_t offset;

						foreach(c; text.byWchar)
							wtext[offset++] = c;

						winapi.GlobalUnlock(hglb);
						winapi.SetClipboardData(winapi.CF_UNICODETEXT, hglb);
					}

					winapi.CloseClipboard();
				}
			}
		}
	}
}

class UIInstance_X11 : UIInstance, Feature_Management_Clipboard {
	import cf.spew.implementation.windowing.window_creator : WindowCreatorImpl_X11;
	import cf.spew.implementation.windowing.display : DisplayImpl_X11;
	import cf.spew.implementation.windowing.misc;
	import cf.spew.event_loop.wells.x11;
	import devisualization.bindings.x11;
	import devisualization.image.storage.base : ImageStorageHorizontal;
	import devisualization.image.interfaces : imageObjectFrom;
	import std.typecons : tuple;

	size_t maxClipboardSizeV = size_t.max;

	this(shared(ISharedAllocator) allocator) shared {
		super(allocator);
	}

	~this() {
	}

	override {
		managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) shared {
			return cast(managed!IWindowCreator)managed!WindowCreatorImpl_X11(managers(), tuple(this, alloc), alloc);
		}

		@property {
			managed!IDisplay primaryDisplay(IAllocator alloc = theAllocator()) shared {
				auto screenNumber = x11.XDefaultScreen(x11Display());
				Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
				Window rootWindow = x11.XRootWindowOfScreen(theScreen);

				IDisplay theDisplay;
				int numMonitors;
				XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), rootWindow, true, &numMonitors);

				foreach(i; 0 .. numMonitors) {
					if (monitors[i].primary == 1) {
						theDisplay = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc, this);
						break;
					}
				}

				x11.XRRFreeMonitors(monitors);
				if (theDisplay is null)
					return managed!IDisplay.init;
				else
					return managed!IDisplay(theDisplay, managers(ReferenceCountedManager()), alloc);
			}

			managed!(IDisplay[]) displays(IAllocator alloc = theAllocator()) shared {
				auto screenNumber = x11.XDefaultScreen(x11Display());
				Screen* theScreen = x11.XScreenOfDisplay(x11Display(), screenNumber);
				Window rootWindow = x11.XRootWindowOfScreen(theScreen);

				int numMonitors;
				XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), rootWindow, true, &numMonitors);

				if (numMonitors == -1)
					return managed!(IDisplay[]).init;

				IDisplay[] ret = alloc.makeArray!IDisplay(cast(size_t)numMonitors);
				foreach(i; 0 .. numMonitors) {
					ret[i] = alloc.make!DisplayImpl_X11(theScreen, &monitors[i], alloc, this);
				}

				x11.XRRFreeMonitors(monitors);
				return managed!(IDisplay[])(ret, managers(ReferenceCountedManager()), alloc);
			}

			managed!(IWindow[]) windows(IAllocator alloc = theAllocator()) shared {
				GetWindows_X11 ctx;
				ctx.alloc = alloc;
				ctx.uiInstance = this;
				ctx.call;

				return managed!(IWindow[])(ctx.windows, managers(ReferenceCountedManager()), alloc);
			}
		}

		// clipboard

		shared(Feature_Management_Clipboard) __getFeatureClipboard() shared {
			return null;
		}

		@property {
			void maxClipboardDataSize(size_t amount) shared { maxClipboardSizeV = amount; }

			size_t maxClipboardDataSize() shared { return maxClipboardSizeV; }

			managed!string clipboardText(IAllocator alloc) shared {
				return managed!string.init;
			}

			void clipboardText(scope string text) shared {}
		}
	}
}

final class UIInstance_X11_Libnotify : UIInstance_X11, Feature_Notification {
    import devisualization.bindings.libnotify.loader;

    private char[] postName;

    this(shared(ISharedAllocator) allocator) shared {
        import std.file : thisExePath;
        import std.path : baseName, stripExtension;

        super(allocator);

        if (libnotify.notify_is_initted() == 0) {
            string preName = thisExePath.baseName.stripExtension;
            postName = cast(shared)allocator.makeArray!char(preName.length + 1);
            postName[0 .. $-1] = preName[];
            postName[$-1] = '\0';

            libnotify.notify_init(cast(char*)postName.ptr);
        }
    }

    ~this() {
        // TODO: notification area
        (cast(shared)this).clearNotifications();
        libnotify.notify_uninit();

        if (postName !is null)
            allocator.dispose(postName);
    }

    // notifications
    @property {
        shared(ImageStorage!RGBA8) getNotificationIcon(shared(ISharedAllocator) alloc) shared {
            // TODO: https://people.gnome.org/~mccann/docs/notification-spec/notification-spec-latest.html
            assert(0);
        }

        void setNotificationIcon(shared(ImageStorage!RGBA8) icon, shared(ISharedAllocator) alloc) shared {
            // TODO: https://people.gnome.org/~mccann/docs/notification-spec/notification-spec-latest.html
        }
    }

    void notify(shared(ImageStorage!RGBA8) icon, shared(dstring) title, shared(dstring) text, shared(ISharedAllocator) alloc) shared {
        // notify_notification_new
        // https://github.com/GNOME/libnotify/blob/master/tests/test-xy-stress.c#L51
        // g_signal_connect G_OBJECT G_CALLBACK g_free g_strndup
        assert(0);
    }

    void clearNotifications() shared {
        // use a list so we can remove all of them as libnotify doesn't know how to
        // g_object_unref
        assert(0);
    }
}

abstract class StreamsInstance : Management_Streams {
	import cf.spew.streams;
	import std.socket : Address;
	import stdx.allocator : ISharedAllocator, processAllocator;

	shared(ISharedAllocator) allocator;

	~this() {
		(cast(shared)this).forceCloseAll();
	}

	this(shared(ISharedAllocator) allocator) shared {
		this.allocator = allocator;
	}

	void forceCloseAll() shared {
		import cf.spew.implementation.streams.base : StreamPoint;
		StreamPoint.closeAllInstances();
	}
}

class StreamsInstance_LibUV : StreamsInstance {
	import cf.spew.streams;

	this(shared(ISharedAllocator) allocator) shared {
		super(allocator);
	}

	managed!ISocket_TCPServer tcpServer(Address address, ushort listBacklogAmount=64, IAllocator alloc=theAllocator()) shared {
		import cf.spew.implementation.streams.tcp_server : LibUVTCPServer;
		return LibUVTCPServer.create(address, listBacklogAmount, alloc);
	}
	managed!ISocket_TCP tcpConnect(Address address, IAllocator alloc=theAllocator()) shared {
		import cf.spew.implementation.streams.tcp : LibUVTCPSocket;
		return LibUVTCPSocket.create(address, alloc);
	}
	managed!ISocket_UDPLocalPoint udpLocalPoint(Address address, IAllocator alloc=theAllocator()) shared {
		import cf.spew.implementation.streams.udp : LibUVUDPLocalPoint;
		return LibUVUDPLocalPoint.create(address, alloc);
	}

	managed!(managed!Address[]) allLocalAddress(IAllocator alloc=theAllocator()) shared {
		import devisualization.bindings.libuv;
		if (alloc is null) return managed!(managed!Address[]).init;

		managed!Address[] ret;

		int count;
		uv_interface_address_t* addresses;
		libuv.uv_interface_addresses(&addresses, &count);

		ret = cast(managed!Address[])alloc.makeArray!(ubyte)(count * managed!Address.sizeof);
		foreach(i, v; addresses[0 .. count]) {
			if (v.address.address4.sin_family == AF_INET) {
				ret[i] = cast(managed!Address)managed!InternetAddress(alloc.make!InternetAddress(v.address.address4), managers(), alloc);
			} else if (v.address.address4.sin_family == AF_INET6) {
				ret[i] = cast(managed!Address)managed!Internet6Address(alloc.make!Internet6Address(v.address.address6), managers(), alloc);
			} else {
				ret[i] = managed!Address.init;
			}
		}

		libuv.uv_free_interface_addresses(addresses, count);
		return managed!(managed!Address[])(ret, managers(), alloc);
	}
}

class Miscellaneous_Instance : Management_Miscellaneous {
	import cf.spew.miscellaneous;
	import std.experimental.containers.map;
	import core.time : Duration;

	shared(SharedMap!(size_t, ITimer)) timerToIdMapper;

	this(shared(ISharedAllocator) alloc) shared {
		timerToIdMapper = SharedMap!(size_t, ITimer)(alloc);
	}

	managed!ITimer createTimer(Duration timeout, bool hintSystemWait=true, IAllocator alloc=theAllocator()) shared {
		import cf.spew.implementation.misc.timer;
		ITimer ret;

		if (hintSystemWait) {
			version(Windows) {
				ret = alloc.make!WinAPITimer(this, timeout);
			}
		}

		if (ret is null) {
			ret = alloc.make!LibUVTimer(timeout);
		}

		return managed!ITimer(ret, managers(), alloc);
	}

	managed!IFileSystemWatcher createFileSystemWatcher(string path, IAllocator alloc=theAllocator()) shared {
		import cf.spew.implementation.misc.filewatcher;
		IFileSystemWatcher ret;

		ret = alloc.make!LibUVFileSystemWatcher(path, alloc);

		return managed!IFileSystemWatcher(ret, managers(), alloc);
	}
}
