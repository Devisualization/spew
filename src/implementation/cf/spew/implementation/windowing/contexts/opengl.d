/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.implementation.windowing.contexts.opengl;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features.opengl;
import cf.spew.implementation.windowing.window : WindowImpl;
import x11b = devisualization.bindings.x11;

class OpenGLContextImpl : IContext, Have_OpenGL, Feature_OpenGL {
	private {
		OpenGLVersion version_;
		OpenGL_Context_Callbacks* callbacks;
	}

	this(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
		this.version_ = version_;
		this.callbacks = callbacks;
	}

	Feature_OpenGL __getFeatureOpenGL() {
		return this;
	}

	bool readyToBeUsed() { assert(0); }
	void activate() { assert(0); }
	void deactivate() { assert(0); }
}

version(Windows) {
	import core.sys.windows.windows : HWND, HDC, HGLRC,
		PIXELFORMATDESCRIPTOR, PFD_DRAW_TO_WINDOW, PFD_SUPPORT_OPENGL, PFD_DOUBLEBUFFER, PFD_TYPE_RGBA, PFD_MAIN_PLANE,
		ChoosePixelFormat, SetPixelFormat, GetDC, SwapBuffers, IsWindowVisible;

	ubyte 
		WinAPI_ColorBits = 32,
		WinAPI_Depth = 24,
		WinAPI_Stencil = 8,
		WinAPI_AntiAlias = 1;

	enum {
		WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091,
		WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092,
	}

	final class OpenGLContextImpl_WinAPI : OpenGLContextImpl {
		private {
			HDC _hdc;
			HGLRC _context;
			HWND hwnd;

			extern(Windows) HGLRC function(HDC) wglCreateContext;
			extern(Windows) bool function(HDC, HGLRC) wglMakeCurrent;
			extern(Windows) bool function(HGLRC) wglDeleteContext;
			extern(Windows) HGLRC function(HDC, HGLRC, int*) wglCreateContextAttribsARB;

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
			bool readyToBeUsed() { return _context !is null; }

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

			pixelAttribs = PIXELFORMATDESCRIPTOR(
				PIXELFORMATDESCRIPTOR.sizeof,
				1,
				PFD_DRAW_TO_WINDOW  | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
				PFD_TYPE_RGBA,
				WinAPI_ColorBits,
				0, 0, 0, 0, 0, 0,
				0,
				0,
				0,
				0, 0, 0, 0,
				WinAPI_Depth,
				WinAPI_Stencil,
				WinAPI_AntiAlias,
				PFD_MAIN_PLANE,
				0,
				0, 0, 0
			);

			if (callbacks.loadSymbol !is null &&
				(wglCreateContext is null)) {
				wglCreateContext = cast(typeof(wglCreateContext))callbacks.loadSymbol("wglCreateContext");
				wglMakeCurrent = cast(typeof(wglMakeCurrent))callbacks.loadSymbol("wglMakeCurrent");
				wglDeleteContext = cast(typeof(wglDeleteContext))callbacks.loadSymbol("wglDeleteContext");
			}

			if (wglCreateContext !is null &&
				wglMakeCurrent !is null &&
				wglDeleteContext !is null) {

				auto format = ChoosePixelFormat(_hdc, &pixelAttribs);
				SetPixelFormat(_hdc, format, &pixelAttribs);

				HGLRC fallbackRC = wglCreateContext(_hdc);
				HGLRC preferredRC;

				wglMakeCurrent(_hdc, fallbackRC);
				if (callbacks.onLoad !is null)
					callbacks.onLoad("wglGetProcAddress");

				wglCreateContextAttribsARB = cast(typeof(wglCreateContextAttribsARB))callbacks.loadSymbol("wglCreateContextAttribsARB");
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
}

final class OpenGLContextImpl_X11 : OpenGLContextImpl {
    import cf.spew.event_loop.wells.x11;

    private {
        enum {
            GLX_CONTEXT_MAJOR_VERSION_ARB = 0x2091,
            GLX_CONTEXT_MINOR_VERSION_ARB = 0x2092,
            GLX_RGBA = 4,
            GLX_DEPTH_SIZE = 12,
            GLX_DOUBLEBUFFER = 5,
            GLX_X_RENDERABLE = 0x8012,
            GLX_DRAWABLE_TYPE = 0x8010,
            GLX_RENDER_TYPE = 0x8011,
            GLX_X_VISUAL_TYPE = 0x22,
            GLX_WINDOW_BIT = 0x00000001,
            GLX_RGBA_BIT = 0x00000001,
            GLX_TRUE_COLOR = 0x8002,
            GLX_RED_SIZE = 8,
            GLX_GREEN_SIZE = 9,
            GLX_BLUE_SIZE = 10,
            GLX_ALPHA_SIZE = 11,
            GLX_STENCIL_SIZE = 13,
        }

        struct __GLXcontextRec;
        alias GLXContext = __GLXcontextRec*;
        struct __GLXFBConfigRec;
        alias GLXFBConfig = __GLXFBConfigRec*;
        alias GLXDrawable = x11b.XID;

        x11b.Window whandle;
        GLXContext _context;
        int[] attribs = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, x11b.None];
        int[] arbAttribs = [GLX_CONTEXT_MAJOR_VERSION_ARB, 1, GLX_CONTEXT_MINOR_VERSION_ARB, 0, 0];
        int[] visualAttribs = [
            GLX_X_RENDERABLE, true,
            GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
            GLX_RENDER_TYPE, GLX_RGBA_BIT,
            GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR,
            GLX_RED_SIZE, 8,
            GLX_GREEN_SIZE, 8,
            GLX_BLUE_SIZE, 8,
            GLX_ALPHA_SIZE, 8,
            GLX_DEPTH_SIZE, 24,
            GLX_STENCIL_SIZE, 8,
            GLX_DOUBLEBUFFER, true,
            //GLX_SAMPLE_BUFFERS  , 1,
            //GLX_SAMPLES         , 4,
            x11b.None
        ];

        x11b.XVisualInfo* visual;

        extern(C) GLXContext function(x11b.Display* dpy, x11b.XVisualInfo* vis, GLXContext shareList, x11b.Bool direct) glXCreateContext;
        extern(C) x11b.Bool function(x11b.Display* dpy, GLXDrawable drawable, GLXContext ctx) glXMakeCurrent;
        extern(C) void function(x11b.Display* dpy, GLXContext ctx) glXDestroyContext;
        extern(C) x11b.XVisualInfo* function(x11b.Display* dpy, int screen, int* attribList) glXChooseVisual;
        extern(C) void function(x11b.Display* dpy, GLXDrawable drawable) glXSwapBuffers;

        extern(C) GLXContext function(x11b.Display* dpy, GLXFBConfig config, GLXContext share_context, x11b.Bool direct, const int* attrib_list) glXCreateContextAttribsARB;
        extern(C) GLXFBConfig* function(x11b.Display* dpy, int screen, const int* attrib_list, int* nelements) glXChooseFBConfig;
        extern(C) x11b.XVisualInfo* function(x11b.Display* dpy, GLXFBConfig config) glXGetVisualFromFBConfig;
        extern(C) int function(x11b.Display* dpy, GLXFBConfig config, int attribute, int* value) glXGetFBConfigAttrib;
    }

    this(x11b.Window whandle, OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
        super(version_, callbacks);

        this.whandle = whandle;
        arbAttribs[1] = version_.major;
        arbAttribs[3] = version_.minor;
    }

    ~this() {
        if (visual !is null) {
            x11b.x11.XFree(visual);
        }

        if (_context !is null) {
            if (callbacks.onUnload !is null)
                callbacks.onUnload();
            glXMakeCurrent(x11Display(), 0, null);
            glXDestroyContext(x11Display(), _context);
        }
    }

    override {
        bool readyToBeUsed() { return _context !is null; }

        void activate() {
            if (_context is null)
                attemptCreation();

            if (_context !is null) {
                glXMakeCurrent(x11Display(), cast(GLXDrawable)whandle, _context);
                if (callbacks.onActivate !is null)
                    callbacks.onActivate();
            }
        }

        void deactivate() {
            if (callbacks.onDeactivate !is null)
                callbacks.onDeactivate();
            if (glXMakeCurrent !is null && glXSwapBuffers !is null) {
                glXSwapBuffers(x11Display(), cast(GLXDrawable)whandle);
                glXMakeCurrent(x11Display(), 0, null);
            }
        }
    }

    void attemptCreation() {
        if (callbacks.onLoadOfSymbols !is null)
            callbacks.onLoadOfSymbols();

        if (callbacks.loadSymbol !is null &&
            (glXCreateContext is null)) {
            glXCreateContext = cast(typeof(glXCreateContext))callbacks.loadSymbol("glXCreateContext");
            glXMakeCurrent = cast(typeof(glXMakeCurrent))callbacks.loadSymbol("glXMakeCurrent");
            glXDestroyContext = cast(typeof(glXDestroyContext))callbacks.loadSymbol("glXDestroyContext");
            glXSwapBuffers = cast(typeof(glXSwapBuffers))callbacks.loadSymbol("glXSwapBuffers");
            glXChooseVisual = cast(typeof(glXChooseVisual))callbacks.loadSymbol("glXChooseVisual");
        }

        if (glXCreateContext !is null &&
            glXMakeCurrent !is null &&
            glXDestroyContext !is null &&
            glXSwapBuffers !is null &&
            glXChooseVisual !is null) {

            if (visual !is null)
                x11b.x11.XFree(visual);
            visual = glXChooseVisual(x11Display(), x11b.x11.XDefaultScreen(x11Display()), attribs.ptr);
            x11b.XVisualInfo* prefferedVisual;

            GLXContext fallbackRC = glXCreateContext(x11Display(), visual, null, true);
            GLXContext preferredRC;

            glXMakeCurrent(x11Display(), cast(GLXDrawable)whandle, fallbackRC);
            if (callbacks.onLoad !is null)
                callbacks.onLoad("glXGetProcAddress");

            _context = fallbackRC;

            /+wglCreateContextAttribsARB = cast(typeof(wglCreateContextAttribsARB))callbacks.loadSymbol("wglCreateContextAttribsARB");
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
                _context = fallbackRC;+/
        }
    }
}
