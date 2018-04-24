/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.display;
import cf.spew.implementation.instance;
import cf.spew.implementation.windowing.misc;
import cf.spew.ui;
import cf.spew.ui.rendering : vec2;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, make, makeArray;

abstract class DisplayImpl : IDisplay {
	package(cf.spew) {
		IAllocator alloc;
		shared(UIInstance) uiInstance;

		managed!string name_;
		bool primaryDisplay_;
		vec2!ushort size_;
		uint refreshRate_;
	}

	@property {
		managed!string name() { return name_; }
		vec2!ushort size() { return size_; }
		uint refreshRate() { return refreshRate_; }
		bool isPrimary() { return primaryDisplay_; }
	}
}

version(Windows) {
	import core.sys.windows.windows : MONITORINFOEXA, GetMonitorInfoA, MONITORINFOF_PRIMARY,
		DEVMODEA, EnumDisplaySettingsA, ENUM_CURRENT_SETTINGS, CreateDCA, LONG, HMONITOR,
		DWORD, HDC, DeleteDC;

	final class DisplayImpl_WinAPI : DisplayImpl, Feature_Display_ScreenShot, Have_Display_ScreenShot {
		HMONITOR hMonitor;

		this(HMONITOR hMonitor, IAllocator alloc, shared(UIInstance) uiInstance) {
			import std.string : fromStringz;

			this.alloc = alloc;
			this.uiInstance = uiInstance;

			this.hMonitor = hMonitor;

			MONITORINFOEXA info;
			info.cbSize = MONITORINFOEXA.sizeof;
			GetMonitorInfoA(hMonitor, &info);

			char[] temp = info.szDevice.ptr.fromStringz;
			char[] name_ = alloc.makeArray!char(temp.length + 1);
			name_[0 .. $-1] = temp[];
			name_[$-1] = '\0';

			this.name_ = managed!string(cast(string)name_[0 .. $-1], managers(), alloc);

			LONG sizex = info.rcMonitor.right - info.rcMonitor.left;
			LONG sizey = info.rcMonitor.bottom - info.rcMonitor.top;

			if (sizex > 0 && sizey > 0) {
				size_.x = cast(ushort)sizex;
				size_.y = cast(ushort)sizey;
			}

			primaryDisplay_ = (info.dwFlags & MONITORINFOF_PRIMARY) == MONITORINFOF_PRIMARY;

			DEVMODEA devMode;
			devMode.dmSize = DEVMODEA.sizeof;
			EnumDisplaySettingsA(name_.ptr, ENUM_CURRENT_SETTINGS, &devMode);
			refreshRate_ = devMode.dmDisplayFrequency;
		}

		@property {
			uint luminosity() {
				DWORD pdwMonitorCapabilities, pdwSupportedColorTemperatures;
				DWORD pdwMinimumBrightness, pdwCurrentBrightness, pdwMaxiumumBrightness;
				PHYSICAL_MONITOR[1] pPhysicalMonitorArray;

				if (GetPhysicalMonitorsFromHMONITOR is null || GetMonitorCapabilities is null || GetMonitorBrightness is null) {
					return 10;
				} else {
					bool success = cast(bool)GetPhysicalMonitorsFromHMONITOR(hMonitor, pPhysicalMonitorArray.length, pPhysicalMonitorArray.ptr);
					if (!success)
						return 10;

					success = cast(bool)GetMonitorCapabilities(pPhysicalMonitorArray[0].hPhysicalMonitor, &pdwMonitorCapabilities, &pdwSupportedColorTemperatures);
					if (!success || (pdwMonitorCapabilities & MC_CAPS_BRIGHTNESS) == 0)
						return 10;

					success = cast(bool)GetMonitorBrightness(pPhysicalMonitorArray[0].hPhysicalMonitor, &pdwMinimumBrightness, &pdwCurrentBrightness, &pdwMaxiumumBrightness);
					if (!success)
						return 10;

					return pdwCurrentBrightness;
				}
			}

			managed!(IWindow[]) windows() {
				GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc, uiInstance, this);
				ctx.call;
				return managed!(IWindow[])(ctx.windows, managers(), alloc);
			}

			size_t __handle() {
				return cast(size_t)hMonitor;
			}
		}

		Feature_Display_ScreenShot __getFeatureScreenShot() {
			return this;
		}

		ImageStorage!RGB8 screenshot(IAllocator alloc = null) {
			if (alloc is null)
				alloc = this.alloc;

			if (size_.x < 0 || size_.y < 0)
				return null;

			HDC hScreenDC = CreateDCA(name_.ptr, null, null, null);
			auto storage = screenshotImpl_WinAPI(alloc, hScreenDC, size_.x, size_.y);
			DeleteDC(hScreenDC);
			return storage;
		}

		IDisplay dup(IAllocator alloc) {
			return alloc.make!DisplayImpl_WinAPI(hMonitor, alloc, uiInstance);
		}
	}
}

final class DisplayImpl_X11 : DisplayImpl, Feature_Display_ScreenShot, Have_Display_ScreenShot {
	import cf.spew.event_loop.wells.x11;
	import devisualization.bindings.x11;

	Screen* screen;
	RROutput rrOutput;

	int x, y;
	int width, height;

	this(DisplayImpl_X11 other) {
		this.alloc = other.alloc;
		this.uiInstance = other.uiInstance;

		this.screen = other.screen;
		this.rrOutput = other.rrOutput;
		this.x = other.x;
		this.y = other.y;
		this.width = other.width;
		this.height = other.height;
		this.name_ = other.name_;
		this.primaryDisplay_ = other.primaryDisplay_;
		this.size_ = other.size_;
		this.refreshRate_ = other.refreshRate_;
	}

	this(Screen* screen, XRRMonitorInfo* monitor, IAllocator alloc, shared(UIInstance) uiInstance) {
		import core.stdc.string : strlen;
		this.screen = screen;
		this.alloc = alloc;
		this.uiInstance = uiInstance;

		auto root = x11.XRootWindowOfScreen(screen);
		XRRScreenConfiguration* screenConfig = x11.XRRGetScreenInfo(x11Display(), root);
		refreshRate_ = x11.XRRConfigCurrentRate(screenConfig);

		// we need this to dectect windows.
		x = monitor.x;
		y = monitor.y;
		width = monitor.width;
		height = monitor.height;

		size_.x = cast(ushort)monitor.width;
		size_.y = cast(ushort)monitor.height;

		char* name = x11.XGetAtomName(x11Display(), monitor.name);
		char[] dupedName = alloc.makeArray!char(strlen(name));
		dupedName[] = name[0 .. dupedName.length];
		name_ = managed!string(cast(string)dupedName, managers(ReferenceCountedManager()), alloc);
		x11.XFree(name);

		primaryDisplay_ = monitor.primary == 1;

		if (monitor.noutput >= 1)
			rrOutput = monitor.outputs[0];
	}

	@property {
		uint luminosity() {
			Atom XA_INTEGER = x11.XInternAtom(x11Display(), "INTEGER", false);
			Atom backlightAtom = x11.XInternAtom(x11Display(), "Backlight", true);
			Atom backlightAtomOld = x11.XInternAtom(x11Display(), "BACKLIGHT", true);

			if (backlightAtom <= 0) {
				backlightAtom = backlightAtomOld;
			}

			if (backlightAtom > 0 && rrOutput > 0) {
				auto root = x11.XRootWindowOfScreen(screen);

				Atom actualType;
				int actualFormat;
				size_t nitems, bytesAfter;
				ubyte* prop;

				x11.XRRGetOutputProperty(x11Display(), rrOutput, backlightAtom,
				  0, 4, false, false, None,
				  &actualType, &actualFormat,
				  &nitems, &bytesAfter, &prop);

				if (actualType != XA_INTEGER || nitems != 1 || actualFormat != 32) {
					if (prop !is null)
						x11.XFree(prop);
					return 10;
				} else {
					import core.stdc.config : c_long;
					c_long ret = *cast(c_long*)prop;
					x11.XFree(prop);
					return cast(uint)ret;
				}
			}

			return 10;
		}

		managed!(IWindow[]) windows() {
			GetWindows_X11 ctx;
			ctx.display = this;
			ctx.uiInstance = uiInstance;
			ctx.alloc = alloc;
			ctx.call;

			return managed!(IWindow[])(ctx.windows, managers(), alloc);
		}

		size_t __handle() {
			return cast(size_t)screen;
		}
	}

	Feature_Display_ScreenShot __getFeatureScreenShot() {
		return this;
	}

	ImageStorage!RGB8 screenshot(IAllocator alloc = null) {
		import devisualization.image : ImageStorage;
		import devisualization.image.storage.base : ImageStorageHorizontal;
		import devisualization.image.interfaces : imageObject;
		import std.experimental.color : RGB8, RGBA8;

		if (alloc is null)
			alloc = this.alloc;

		Window rootWindow = x11.XDefaultRootWindow(x11Display());
		XImage* complete = x11.XGetImage(x11Display(), cast(Drawable)rootWindow, x, y, width, height, AllPlanes, ZPixmap);
		auto storage = imageObject!(ImageStorageHorizontal!RGB8)(size_.x, size_.y, alloc);

		foreach(y; 0 .. height) {
			foreach(x; 0 .. width) {
				auto pix = x11.XGetPixel(complete, x, y);
				storage[x, y] = RGB8(cast(ubyte)((pix & complete.red_mask) >> 16), cast(ubyte)((pix & complete.green_mask) >> 8), cast(ubyte)(pix & complete.blue_mask));
			}
		}

		x11.XFree(complete);
		return storage;
	}

	IDisplay dup(IAllocator alloc) {
		return alloc.make!DisplayImpl_X11(this);
	}
}

