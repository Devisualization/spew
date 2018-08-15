module cf.spew.implementation.windowing.contexts.opengl.winapi;
version (Windows):
import cf.spew.implementation.windowing.contexts.opengl.base;
import cf.spew.ui.context.features.opengl;
import core.sys.windows.windows : HWND, HDC, HGLRC, PIXELFORMATDESCRIPTOR,
    PFD_DRAW_TO_WINDOW, PFD_SUPPORT_OPENGL, PFD_DOUBLEBUFFER, PFD_TYPE_RGBA,
    PFD_MAIN_PLANE, ChoosePixelFormat, SetPixelFormat, GetDC, SwapBuffers,
    IsWindowVisible;

ubyte WinAPI_ColorBits = 32, WinAPI_Depth = 24, WinAPI_Stencil = 8, WinAPI_AntiAlias = 1;

enum {
    WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091,
    WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092,
}

final class OpenGLContextImpl_WinAPI : OpenGLContextImpl {
    private {
        HDC _hdc;
        HGLRC _context;
        HWND hwnd;

        extern (Windows) HGLRC function(HDC) wglCreateContext;
        extern (Windows) bool function(HDC, HGLRC) wglMakeCurrent;
        extern (Windows) bool function(HGLRC) wglDeleteContext;
        extern (Windows) HGLRC function(HDC, HGLRC, int*) wglCreateContextAttribsARB;

        PIXELFORMATDESCRIPTOR pixelAttribs;
        int[] arbAttribs = [WGL_CONTEXT_MAJOR_VERSION_ARB, 1, WGL_CONTEXT_MINOR_VERSION_ARB, 0, 0];
    }

    this(HWND hwnd, OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
        super(version_, callbacks);

        this.hwnd = hwnd;
        arbAttribs[1] = version_.major;
        arbAttribs[3] = version_.minor;
        _hdc = GetDC(hwnd);
    }

    ~this() {
        if (_context !is null) {
            if (callbacks.onUnload !is null)
                callbacks.onUnload();
            wglMakeCurrent(_hdc, null);
            wglDeleteContext(_context);
        }
    }

    override {
        bool readyToBeUsed() {
            return _context !is null;
        }

        void activate() {
            if (_context is null)
                attemptCreation();

            if (_context !is null) {
                wglMakeCurrent(_hdc, _context);
                if (callbacks.onActivate !is null)
                    callbacks.onActivate();
            }
        }

        void deactivate() {
            if (callbacks.onDeactivate !is null)
                callbacks.onDeactivate();
            if (wglMakeCurrent !is null) {
                SwapBuffers(_hdc);
                wglMakeCurrent(null, null);
            }
        }
    }

    void attemptCreation() {
        if (callbacks.onLoadOfSymbols !is null)
            callbacks.onLoadOfSymbols();

        pixelAttribs = PIXELFORMATDESCRIPTOR(PIXELFORMATDESCRIPTOR.sizeof, 1,
                PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
                PFD_TYPE_RGBA, WinAPI_ColorBits, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, WinAPI_Depth, WinAPI_Stencil, WinAPI_AntiAlias,
                PFD_MAIN_PLANE, 0, 0, 0, 0);

        if (callbacks.loadSymbol !is null && (wglCreateContext is null)) {
            wglCreateContext = cast(typeof(wglCreateContext))callbacks.loadSymbol(
                    "wglCreateContext");
            wglMakeCurrent = cast(typeof(wglMakeCurrent))callbacks.loadSymbol("wglMakeCurrent");
            wglDeleteContext = cast(typeof(wglDeleteContext))callbacks.loadSymbol(
                    "wglDeleteContext");
        }

        if (wglCreateContext !is null && wglMakeCurrent !is null && wglDeleteContext !is null) {

            auto format = ChoosePixelFormat(_hdc, &pixelAttribs);
            SetPixelFormat(_hdc, format, &pixelAttribs);

            HGLRC fallbackRC = wglCreateContext(_hdc);
            HGLRC preferredRC;

            wglMakeCurrent(_hdc, fallbackRC);
            if (callbacks.onLoad !is null)
                callbacks.onLoad("wglGetProcAddress");

            wglCreateContextAttribsARB = cast(typeof(wglCreateContextAttribsARB))callbacks.loadSymbol(
                    "wglCreateContextAttribsARB");
            if (wglCreateContextAttribsARB !is null) {
                preferredRC = wglCreateContextAttribsARB(_hdc, null, arbAttribs.ptr);
                if (preferredRC !is null) {
                    wglMakeCurrent(_hdc, preferredRC);
                    if (callbacks.onReload !is null)
                        callbacks.onReload();
                }
            }

            if (preferredRC !is null) {
                _context = preferredRC;
                if (fallbackRC !is null) {
                    wglDeleteContext(fallbackRC);
                }
            } else
                _context = fallbackRC;
        }
    }
}
