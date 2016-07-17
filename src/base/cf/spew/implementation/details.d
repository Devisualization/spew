module cf.spew.implementation.details;

// if you are not part of cf.spew, why do you care about the implementation details?
package(cf.spew):

public import cf.spew.ui;
public import cf.spew.platform;
public import cf.spew.event_loop;
public import std.experimental.graphic.image : ImageStorage;
public import std.experimental.graphic.color : RGB8, RGBA8;
public import std.experimental.containers.list;
public import std.experimental.containers.map;
public import std.experimental.allocator : IAllocator, processAllocator, theAllocator, dispose, make, makeArray, expandArray, shrinkArray;
public import std.experimental.memory.managed;

version(Windows) {
	public import winapi = core.sys.windows.windows;

	pragma(lib, "gdi32");
	pragma(lib, "user32");
	
	public import cf.spew.implementation.features.notifications;
	interface PlatformInterfaces : Feature_Notification, Have_Notification {}
} else {
	interface PlatformInterfaces {}
}
