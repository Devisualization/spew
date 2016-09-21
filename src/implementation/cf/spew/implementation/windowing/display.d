module cf.spew.implementation.windowing.display;
import cf.spew.implementation.instance;
import cf.spew.implementation.windowing.misc;
import cf.spew.ui;
import cf.spew.ui.rendering : vec2;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGB8;
import std.experimental.memory.managed;
import std.experimental.allocator : IAllocator, make, makeArray;

abstract class DisplayImpl : IDisplay {
	package(cf.spew) {
		IAllocator alloc;
		UIInstance uiInstance;

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

	final class DisplayImpl_WinAPI : DisplayImpl, Feature_ScreenShot, Have_ScreenShot {
		HMONITOR hMonitor;
		
		this(HMONITOR hMonitor, IAllocator alloc, UIInstance uiInstance) {
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
			
			this.name_ = managed!string(cast(string)name_[0 .. $-1], managers(), Ownership.Secondary, alloc);
			
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
			
			managed!(IWindow[]) windows() {
				/+GetWindows ctx = GetWindows(alloc, cast()platform, cast()this);
				ctx.call;
				return managed!(IWindow[])(ctx.windows, managers(), Ownership.Secondary, alloc);+/
				return managed!(IWindow[]).init;
			}
			
			void* __handle() {
				return &hMonitor;
			}
		}
		
		Feature_ScreenShot __getFeatureScreenShot() {
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