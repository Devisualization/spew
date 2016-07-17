module cf.spew.platform;
import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
import std.experimental.memory.managed;
import std.experimental.allocator : IAllocator, processAllocator, theAllocator;
import std.datetime : Duration, seconds;
import core.atomic : atomicStore, atomicLoad;

///
interface IPlatform {
	///
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator());
	
	///
	IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()); // completely up to platform implementation to what the defaults are
	
	///
	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator());
	
	///
	IWindow createAWindow(IAllocator alloc = theAllocator()); // completely up to platform implementation to what the defaults are
	
	@property {
		///
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator());
		
		///
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator());
		
		///
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator());
	}

	///
	final void setAsTheImplementation() { atomicStore(thePlatform_, cast(shared)this); }
}

///
IPlatform thePlatform() { return atomicLoad(thePlatform_); }
///
IPlatform defaultPlatform() { return atomicLoad(defaultPlatform_); }

private shared {
	IPlatform defaultPlatform_;
	IPlatform thePlatform_;

	shared static this() {
		import cf.spew.implementation.platform;
		shared PlatformImpl impl = cast(shared)new PlatformImpl;

		atomicStore(defaultPlatform_, impl);
		atomicStore(thePlatform_, impl);
	}
}
