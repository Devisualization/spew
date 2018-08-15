module cf.spew.implementation.windowing.display.winapi;
version (Windows):
import cf.spew.implementation.windowing.display.base;
import cf.spew.implementation.windowing.utilities.winapi : PHYSICAL_MONITOR,
    GetPhysicalMonitorsFromHMONITOR, GetMonitorCapabilities,
    GetMonitorBrightness, MC_CAPS_BRIGHTNESS, GetWindows_WinAPI,
    screenshotImpl_WinAPI;
import cf.spew.ui.display.defs;
import cf.spew.ui.display.features.screenshot;
import cf.spew.ui.window.defs : IWindow;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8;
import stdx.allocator : IAllocator, make, makeArray;
import core.sys.windows.windows : MONITORINFOEXA, GetMonitorInfoA,
    MONITORINFOF_PRIMARY, DEVMODEA, EnumDisplaySettingsA, ENUM_CURRENT_SETTINGS,
    CreateDCA, LONG, HMONITOR, DWORD, HDC, DeleteDC;

final class DisplayImpl_WinAPI : DisplayImpl, Feature_Display_ScreenShot, Have_Display_ScreenShot {
    HMONITOR hMonitor;

    this(HMONITOR hMonitor, IAllocator alloc) {
        import std.string : fromStringz;

        this.alloc = alloc;
        this.hMonitor = hMonitor;

        MONITORINFOEXA info;
        info.cbSize = MONITORINFOEXA.sizeof;
        GetMonitorInfoA(hMonitor, &info);

        char[] temp = info.szDevice.ptr.fromStringz;
        char[] name_ = alloc.makeArray!char(temp.length + 1);
        name_[0 .. $ - 1] = temp[];
        name_[$ - 1] = '\0';

        this.name_ = managed!string(cast(string)name_[0 .. $ - 1], managers(), alloc);

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

            if (GetPhysicalMonitorsFromHMONITOR is null ||
                    GetMonitorCapabilities is null || GetMonitorBrightness is null) {
                return 10;
            } else {
                bool success = cast(bool)GetPhysicalMonitorsFromHMONITOR(hMonitor,
                        pPhysicalMonitorArray.length, pPhysicalMonitorArray.ptr);
                if (!success)
                    return 10;

                success = cast(bool)GetMonitorCapabilities(pPhysicalMonitorArray[0].hPhysicalMonitor,
                        &pdwMonitorCapabilities, &pdwSupportedColorTemperatures);
                if (!success || (pdwMonitorCapabilities & MC_CAPS_BRIGHTNESS) == 0)
                    return 10;

                success = cast(bool)GetMonitorBrightness(pPhysicalMonitorArray[0].hPhysicalMonitor,
                        &pdwMinimumBrightness, &pdwCurrentBrightness, &pdwMaxiumumBrightness);
                if (!success)
                    return 10;

                return pdwCurrentBrightness;
            }
        }

        managed!(IWindow[]) windows() {
            GetWindows_WinAPI ctx = GetWindows_WinAPI(alloc, this);
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
        return alloc.make!DisplayImpl_WinAPI(hMonitor, alloc);
    }
}
