module cf.spew.implementation.platform;
import cf.spew.ui : IWindow, IDisplay, IWindowCreator, IRenderPoint, IRenderPointCreator;
import cf.spew.platform;
import std.experimental.memory.managed;
import std.experimental.allocator : IAllocator, processAllocator, theAllocator;

class PlatformImpl : IPlatform {
	managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator());
	IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()); // completely up to platform implementation to what the defaults are
	managed!IWindowCreator createWindow(IAllocator alloc = theAllocator());
	IWindow createAWindow(IAllocator alloc = theAllocator()); // completely up to platform implementation to what the defaults are
	
	@property {
		managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator());
		managed!(IDisplay[]) displays(IAllocator alloc = processAllocator());
		managed!(IWindow[]) windows(IAllocator alloc = processAllocator());
	}
}