module cf.spew.implementation.windowing.display.base;
import cf.spew.ui.display.defs : IDisplay;
import cf.spew.ui.rendering : vec2;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator;

abstract class DisplayImpl : IDisplay {
    package(cf.spew.implementation) {
        IAllocator alloc;

        managed!string name_;
        bool primaryDisplay_;
        vec2!ushort size_;
        uint refreshRate_;
    }

    @property {
        managed!string name() {
            return name_;
        }

        vec2!ushort size() {
            return size_;
        }

        uint refreshRate() {
            return refreshRate_;
        }

        bool isPrimary() {
            return primaryDisplay_;
        }
    }
}
