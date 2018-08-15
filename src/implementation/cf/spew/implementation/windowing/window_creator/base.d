module cf.spew.implementation.windowing.window_creator.base;
import cf.spew.ui.window.defs : IWindowCreator;
import cf.spew.ui.context.features;
import cf.spew.ui.rendering : vec2, IRenderPoint;
import cf.spew.ui.display.defs : IDisplay;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.window.features.cursor;
import cf.spew.ui.window.styles;
import devisualization.image : ImageStorage;
import devisualization.util.core.memory.managed;
import stdx.allocator : IAllocator, dispose;
import std.experimental.color : RGBA8;

abstract class WindowCreatorImpl : IWindowCreator, Have_CustomCtx {
    package(cf.spew) {
        vec2!ushort size_ = vec2!ushort(cast(short)800, cast(short)600);
        vec2!short location_;
        IDisplay display_;
        IWindow parentWindow_;
        IAllocator alloc;

        ImageStorage!RGBA8 icon;

        WindowCursorStyle cursorStyle = WindowCursorStyle.Standard;
        ImageStorage!RGBA8 cursorIcon;
        vec2!ushort customIconHotspot;

        WindowStyle windowStyle = WindowStyle.Dialog;

        bool useVRAMContext, vramWithAlpha;
        bool shouldAutoLockCursor;

        bool useOGLContext;
        OpenGLVersion oglVersion;
        OpenGL_Context_Callbacks* oglCallbacks;

        managed!ICustomContext customContext;

        bool shouldAssignMenu;
    }

    this(IAllocator alloc) {
        this.alloc = alloc;
        useVRAMContext = true;
    }

    ~this() {
        if (cursorIcon !is null)
            alloc.dispose(cursorIcon);
    }

    @property {
        void size(vec2!ushort v) {
            size_ = v;
        }

        void location(vec2!short v) {
            location_ = v;
        }

        void display(IDisplay v) {
            display_ = v;
        }

        void allocator(IAllocator v) {
            alloc = v;
        }
    }

    void assignCustomContext(managed!ICustomContext ctx) {
        customContext = ctx;
        useOGLContext = false;
        useVRAMContext = false;
    }

    void parentWindow(IWindow window) {
        this.parentWindow_ = window;
    }

    managed!IRenderPoint create() {
        return cast(managed!IRenderPoint)createWindow();
    }
}
