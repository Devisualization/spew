module cf.spew.implementation.windowing.contexts.opengl.x11;
version (Posix)  : import cf.spew.implementation.windowing.contexts.opengl.base;
import cf.spew.implementation.windowing.window_creator.x11;
import cf.spew.event_loop.wells.x11;
import cf.spew.ui.context.features.opengl;
import cf.spew.ui.rendering : IRenderPointCreator;
import cf.spew.ui.context.defs : IPlatformData;
import x11b = devisualization.bindings.x11;

final class OpenGLContextImpl_X11 : OpenGLContextImpl, IPlatformData {
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
            GLX_SAMPLE_BUFFERS = 100000,
            GLX_SAMPLES = 100001,
            GL_VERSION = 0x1F02,
        }

        struct __GLXcontextRec;
        alias GLXContext = __GLXcontextRec*;
        struct __GLXFBConfigRec;
        alias GLXFBConfig = __GLXFBConfigRec*;
        alias GLXDrawable = x11b.XID;

        x11b.Window whandle;
        GLXContext _context;
        x11b.XVisualInfo* visualInfo;
        bool disableContext;

        int[5] attribs = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, x11b.None];
        int[5] arbAttribs = [GLX_CONTEXT_MAJOR_VERSION_ARB, 1,
            GLX_CONTEXT_MINOR_VERSION_ARB, 0, 0];
        int[19] visualAttribs = [
            GLX_X_RENDERABLE, x11b.True, GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
            GLX_RENDER_TYPE, GLX_RGBA_BIT, GLX_X_VISUAL_TYPE,
            GLX_TRUE_COLOR, GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE,
            8, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, x11b.True, x11b.None
        ];

        extern (C) GLXContext function(x11b.Display* dpy,
                x11b.XVisualInfo* vis, GLXContext shareList, x11b.Bool direct) glXCreateContext;
        extern (C) x11b.Bool function(x11b.Display* dpy, GLXDrawable drawable,
                GLXContext ctx) glXMakeCurrent;
        extern (C) void function(x11b.Display* dpy, GLXContext ctx) glXDestroyContext;
        extern (C) x11b.XVisualInfo* function(x11b.Display* dpy, int screen,
                int* attribList) glXChooseVisual;
        extern (C) void function(x11b.Display* dpy, GLXDrawable drawable) glXSwapBuffers;

        extern (C) GLXContext function(x11b.Display* dpy, GLXFBConfig config,
                GLXContext share_context, x11b.Bool direct, const int* attrib_list) glXCreateContextAttribsARB;
        extern (C) GLXFBConfig* function(x11b.Display* dpy, int screen,
                const int* attrib_list, int* nelements) glXChooseFBConfig;
        extern (C) x11b.XVisualInfo* function(x11b.Display* dpy,
                GLXFBConfig config) glXGetVisualFromFBConfig;
        extern (C) int function(x11b.Display* dpy, GLXFBConfig config, int attribute, int* value) glXGetFBConfigAttrib;
        extern (C) ubyte* function(int) glGetString;
    }

    this(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
        super(version_, callbacks);

        arbAttribs[1] = version_.major;
        arbAttribs[3] = version_.minor;
    }

    ~this() {
        if (visualInfo !is null) {
            x11b.x11.XFree(visualInfo);
        }

        if (_context !is null) {
            if (callbacks.onUnload !is null)
                callbacks.onUnload();
            glXMakeCurrent(x11Display(), 0, null);
            glXDestroyContext(x11Display(), _context);
        }
    }

    override {
        bool readyToBeUsed() {
            // an extra check, to out right disable this context
            return _context !is null;
        }

        void activate() {
            if (disableContext)
                return;
            if (_context is null)
                attemptCreation();

            if (_context !is null && whandle != x11b.None) {
                glXMakeCurrent(x11Display(), cast(GLXDrawable) whandle, _context);
                if (callbacks.onActivate !is null)
                    callbacks.onActivate();
            }
        }

        void deactivate() {
            if (callbacks.onDeactivate !is null)
                callbacks.onDeactivate();
            if (glXMakeCurrent !is null && glXSwapBuffers !is null && whandle != x11b.None) {
                glXSwapBuffers(x11Display(), cast(GLXDrawable) whandle);
                glXMakeCurrent(x11Display(), 0, null);
            }
        }
    }

    void attemptCreation1() {
        if (glXCreateContext !is null || callbacks.loadSymbol is null)
            return;

        glXCreateContext = cast(typeof(glXCreateContext)) callbacks.loadSymbol("glXCreateContext");
        glXMakeCurrent = cast(typeof(glXMakeCurrent)) callbacks.loadSymbol("glXMakeCurrent");
        glXDestroyContext = cast(typeof(glXDestroyContext)) callbacks.loadSymbol(
                "glXDestroyContext");
        glXSwapBuffers = cast(typeof(glXSwapBuffers)) callbacks.loadSymbol("glXSwapBuffers");
        glXChooseVisual = cast(typeof(glXChooseVisual)) callbacks.loadSymbol("glXChooseVisual");
        glGetString = cast(typeof(glGetString)) callbacks.loadSymbol("glGetString");
        glXChooseFBConfig = cast(typeof(glXChooseFBConfig)) callbacks.loadSymbol(
                "glXChooseFBConfig");
        glXGetVisualFromFBConfig = cast(typeof(glXGetVisualFromFBConfig)) callbacks.loadSymbol(
                "glXGetVisualFromFBConfig");
        glXGetFBConfigAttrib = cast(typeof(glXGetFBConfigAttrib)) callbacks.loadSymbol(
                "glXGetFBConfigAttrib");
        glXCreateContextAttribsARB = cast(typeof(glXCreateContextAttribsARB)) callbacks.loadSymbol(
                "glXCreateContextAttribsARB");
    }

    void attemptCreation2() {
        if (glXMakeCurrent is null || glXChooseVisual is null || glXCreateContext is null || glXDestroyContext is null || glGetString is null)
            return;
        if (visualInfo !is null)
            x11b.x11.XFree(visualInfo);
        if (_context !is null)
            glXDestroyContext(x11Display(), _context);

        _context = null;
        visualInfo = null;

        scope(exit) {
            if (_context !is null && whandle != x11b.None && glGetString(GL_VERSION) is null) {
                x11b.x11.XFree(visualInfo);
                glXDestroyContext(x11Display(), _context);
                disableContext = true;
            }
        }

        //

        x11b.XVisualInfo* fallbackVisual = glXChooseVisual(x11Display(),
                x11b.x11.XDefaultScreen(x11Display()), attribs.ptr);
        x11b.XVisualInfo* prefferedVisual;

        assert(fallbackVisual !is null);
        if (fallbackVisual is null)
            return;

        //

        GLXContext fallbackRC = glXCreateContext(x11Display(), fallbackVisual, null, true);
        GLXContext prefferredRC;

        if (fallbackRC is null)
            fallbackRC = glXCreateContext(x11Display(), fallbackVisual, null, false);

        assert(fallbackRC !is null);
        if (fallbackRC is null)
            return;

        //

        int fbcount;
        GLXFBConfig* fbc;
        int best_fbc = -1, worst_fbc = -1, bestNumberSamples = -1, worstNumberSamples = 999;

        if (glXChooseFBConfig is null || glXGetVisualFromFBConfig is null ||
                glXGetFBConfigAttrib is null)
            goto Fallback;

        fbc = glXChooseFBConfig(x11Display(),
                x11b.x11.XDefaultScreen(x11Display()), visualAttribs.ptr, &fbcount);

        if (fbcount == 0)
            goto Fallback;

        foreach (i, fbcV; fbc[0 .. fbcount]) {
            int samplesBuffer, samples;

            x11b.x11.XVisualInfo* vi = glXGetVisualFromFBConfig(x11Display(), fbcV);

            if (vi !is null) {
                // GLX_SAMPLE_BUFFERS == 1
                glXGetFBConfigAttrib(x11Display(), fbcV, GLX_SAMPLE_BUFFERS, &samplesBuffer);
                glXGetFBConfigAttrib(x11Display(), fbcV, GLX_SAMPLES, &samples);

                if (best_fbc < 0 || samplesBuffer && samples > bestNumberSamples) {
                    best_fbc = cast(int) i;
                    bestNumberSamples = samples;
                }

                if (worst_fbc < 0 || !samplesBuffer || samples < worstNumberSamples) {
                    worst_fbc = cast(int) i;
                    worstNumberSamples = samples;
                }

                x11b.x11.XFree(vi);
            }
        }

        if (best_fbc >= 0) {
            GLXFBConfig bestFBC = fbc[best_fbc];
            glXMakeCurrent(x11Display(), 0, null);

            prefferedVisual = glXGetVisualFromFBConfig(x11Display(), bestFBC);

            if (prefferedVisual is null) {
                x11b.x11.XFree(fbc);
                goto Fallback;
            }

            if (glXCreateContextAttribsARB !is null) {
                prefferredRC = glXCreateContextAttribsARB(x11Display(),
                        bestFBC, null, true, cast(const) arbAttribs.ptr);

                if (prefferedVisual is null)
                    prefferredRC = glXCreateContextAttribsARB(x11Display(),
                            bestFBC, null, false, cast(const) arbAttribs.ptr);
            }

            if (prefferredRC is null)
                prefferredRC = glXCreateContext(x11Display(), prefferedVisual, null, true);

            if (prefferredRC is null)
                prefferredRC = glXCreateContext(x11Display(), prefferedVisual, null, false);

            if (prefferedVisual is null) {
                x11b.x11.XFree(prefferedVisual);
                goto Fallback;
            }

            x11b.x11.XSync(x11Display(), false);
            visualInfo = prefferedVisual;
            _context = prefferredRC;

            x11b.x11.XFree(fallbackVisual);
            glXDestroyContext(x11Display(), fallbackRC);
            x11b.x11.XFree(fbc);

            if (callbacks.onLoad !is null)
                callbacks.onLoad("glXGetProcAddress");

            if (whandle != x11b.None) {
                glXMakeCurrent(x11Display(), cast(GLXDrawable) whandle, _context);
                callbacks.onReload();
            }
            return;
        }

        //

    Fallback:
        visualInfo = fallbackVisual;
        _context = fallbackRC;

        if (whandle != x11b.None) {
            glXMakeCurrent(x11Display(), cast(GLXDrawable) whandle, _context);
            callbacks.onReload();
        }
    }

    void attemptCreation() {
        attemptCreation1();
        attemptCreation2();
    }

    bool supportsPlatformData(IRenderPointCreator renderPointCreator, int) {
        return (cast(WindowCreatorImpl_X11) renderPointCreator) !is null;
    }

    void* getPlatformData(IRenderPointCreator renderPointCreator, int x) {
        attemptCreation();
        return visualInfo;
    }

    void setPlatformData(IRenderPointCreator renderPointCreator, int x, void* v) {
        if (glXDestroyContext !is null && _context !is null)
            glXDestroyContext(x11Display(), _context);
        _context = null;
        if (v !is null)
            whandle = *cast(x11b.Window*) v;
    }
}
