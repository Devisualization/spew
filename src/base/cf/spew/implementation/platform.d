module cf.spew.implementation.platform;
import cf.spew.implementation.details;

class PlatformImpl : IPlatform, PlatformInterfaces {
	IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) { return createAWindow(alloc); }
	IWindow createAWindow(IAllocator alloc = theAllocator()) {
		auto creator = createWindow(alloc);
		creator.size = vec2!ushort(cast(short)800, cast(short)600);
		creator.assignVRamContext;
		return creator.createWindow();
	}

	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) { return cast(managed!IRenderPointCreator)createWindow(alloc); }
	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator());
	
	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator());
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator());
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator());
	}

	//

	Feature_Notification __getFeatureNotification() {
		__guardCheck();

		if (impl_windowing == EventSources.WinAPI) {
			return this;
		} else
			return null;
	}

	@property {
		ImageStorage!RGBA8 getNotificationIcon(IAllocator alloc=theAllocator);
		void setNotificationIcon(ImageStorage!RGBA8 icon, IAllocator alloc=theAllocator);
	}

	void notify(ImageStorage!RGBA8 icon, dstring title, dstring text, IAllocator alloc=theAllocator);
	void clearNotifications();

	//

package(cf.spew):
	// don't want people changing the allocator we use after we start using one!
	bool __Initialized;

	IAllocator allocator;
	ImageStorage!RGBA8 taskbarCustomIcon;

	// size_t may need to be replaced at some point with ulong
	Map!(size_t, IWindow) windowToIdMapper = void;

	EventSource impl_windowing;
	// TODO: timers ext.

	version(Windows) {
		IWindow taskbarIconWindow;
		winapi.NOTIFYICONDATAW taskbarIconNID;
	} else {
	}

	// this can be safely inlined!
	pragma(inline, true)
	void __guardCheck() {
		if (!__Initialized)
			__handleGuardCheck();
	}

	void __handleGuardCheck() {
		import cf.spew.event_loop;
		__Initialized = true;
		allocator = processAllocator;

		// initialize global data
		windowToIdMapper = Map!(size_t, IWindow)(allocator);

		// TODO: add event loop consumer

		// make sure our dependencies are loaded

		version(Windows) {
			import cf.spew.event_loop.wells.winapi;
			impl_windowing = EventSources.WinAPI;
			// TODO: timers ext.

			addSource(WinAPI_EventLoop_Source.instance);
			return;
		}

		//
	}
}