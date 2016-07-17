module cf.spew;
public import cf.spew.events;
public import cf.spew.event_loop;
public import cf.spew.ui;
public import cf.spew.platform;
public import std.experimental.memory.managed;
public import std.experimental.allocator : IAllocator, processAllocator, theAllocator;

///
managed!IRenderPointCreator createRenderPoint(IAllocator alloc = theAllocator()) { return thePlatform().createRenderPoint(alloc); }
///
IRenderPoint createARenderPoint(IAllocator alloc = theAllocator()) { return thePlatform().createARenderPoint(alloc); }
///
managed!IWindowCreator createWindow(IAllocator alloc = theAllocator()) { return thePlatform().createWindow(alloc); }
///
IWindow createAWindow(IAllocator alloc = theAllocator()) { return thePlatform().createAWindow(alloc); }
///
managed!IDisplay primaryDisplay(IAllocator alloc = processAllocator()) { return thePlatform().primaryDisplay(alloc); }
///
managed!(IDisplay[]) displays(IAllocator alloc = processAllocator()) { return thePlatform().displays(alloc); }
///
managed!(IWindow[]) windows(IAllocator alloc = processAllocator()) { return thePlatform().windows(alloc); }





