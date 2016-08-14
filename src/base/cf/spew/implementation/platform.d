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

	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) {
		import cf.spew.implementation.windowing.window_creator;
		__guardCheck();

		version(Windows) {
			return cast(managed!IWindowCreator)managed!WindowCreatorImpl_WinAPI(managers(), tuple(this, alloc), alloc);
		}
	}
	
	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator());
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator());
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator());
	}

	//

	Feature_Notification __getFeatureNotification() {
		__guardCheck();

		if (enable_notifications) {
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

	//

	// TODO: timers ext.

	bool enable_notifications;

	//

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

		// luckily our event loop consumer isn't tied to the well.
		// however we really need to tie into the well's internal callbacks
		//  as it allows for proper usage of the message loop.

		// make sure our dependencies are loaded

		version(Windows) {
			import cf.spew.event_loop.wells.winapi;
			// TODO: timers ext.

			addConsumer(allocator.make!EventLoopConsumerImpl_WinAPI(this));
			enable_notifications = true;
			return;
		}

		//
	}
}