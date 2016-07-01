module cf.spew.bindings.vulkan;
public import cf.spew.bindings.vulkan.core;

public import cf.spew.bindings.vulkan.android;
public import cf.spew.bindings.vulkan.mir;
public import cf.spew.bindings.vulkan.wayland;
public import cf.spew.bindings.vulkan.windows;
public import cf.spew.bindings.vulkan.xcb;
public import cf.spew.bindings.vulkan.xlib;

import cf.spew.bindings.autoloader;
import cf.spew.bindings.symbolloader : SELF_SYMBOL_LOOKUP;

/*
 * System libs (if only it makes sense)
 * Then non specific system lib0
 */

version(Android) {
	///
	__gshared static VulkanAndroidLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.android`, `cf.spew.bindings.vulkan.core`])("vulkan.so", SELF_SYMBOL_LOOKUP);
} else version(Windows) {
	///
	__gshared static VulkanWindowsLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.windows`, `cf.spew.bindings.vulkan.core`])("vulkan.dll", SELF_SYMBOL_LOOKUP);
} else {
	///
	__gshared static VulkanMirLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.mir`, `cf.spew.bindings.vulkan.core`])("vulkan.so", SELF_SYMBOL_LOOKUP);
	///
	__gshared static VulkanWaylandLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.wayland`, `cf.spew.bindings.vulkan.core`])("vulkan.so", SELF_SYMBOL_LOOKUP);
	///
	__gshared static VulkanXcbLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.xcb`, `cf.spew.bindings.vulkan.core`])("vulkan.so", SELF_SYMBOL_LOOKUP);
	///
	__gshared static VulkanXlibLoader = new SharedLibAutoLoader!([`cf.spew.bindings.vulkan.xlib`, `cf.spew.bindings.vulkan.core`])("vulkan.so", SELF_SYMBOL_LOOKUP);
}
