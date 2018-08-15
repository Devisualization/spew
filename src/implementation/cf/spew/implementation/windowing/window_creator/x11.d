module cf.spew.implementation.windowing.window_creator.x11;
version (Posix):
import cf.spew.implementation.windowing.window_creator.base;
import cf.spew.implementation.windowing.utilities.x11;
import cf.spew.implementation.windowing.window.x11;
import cf.spew.implementation.windowing.display.x11;
import cf.spew.implementation.windowing.contexts.vram.x11;
import cf.spew.implementation.windowing.contexts.opengl.x11;
import cf.spew.implementation.windowing.contexts.custom;
import cf.spew.ui.window.features.icon;
import cf.spew.ui.window.features.cursor;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.window.styles;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features;
import cf.spew.event_loop.wells.x11;
import devisualization.bindings.x11;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage;
import stdx.allocator : IAllocator, dispose, make;
import std.experimental.color : RGBA8;

final class WindowCreatorImpl_X11 : WindowCreatorImpl, Have_Icon, Have_Cursor,
    Have_Style, Have_VRamCtx, Have_OGLCtx, Feature_Icon, Feature_Cursor, Feature_Style {

        this(IAllocator alloc) {
            super(alloc);
        }

        managed!IWindow createWindow() {
            WindowImpl_X11 ret;
            IContext context;

            int screenNum = x11.XDefaultScreen(x11Display());
            Window parentWindow;

            // get parent window

            Window* parentId;
            if ((cast(WindowImpl_X11)parentWindow_) !is null && parentWindow_ !is null)
                parentId = cast(Window*)parentWindow_.__handle;
            if (parentId is null)
                parentWindow = x11.XRootWindow(x11Display(), screenNum);
            else
                parentWindow = *parentId;

            // where are we putting the window?

            int actualX, actualY;
            uint actualWidth, actualHeight;

            actualX = location_.x;
            actualY = location_.y;
            actualWidth = size_.x;
            actualHeight = size_.y;

            if (windowStyle == WindowStyle.Fullscreen) {
                if (display_ !is null) {
                    if (DisplayImpl_X11 display2 = cast(DisplayImpl_X11)display_) {
                        actualX = location_.x;
                        actualY = location_.y;
                        actualWidth = size_.x;
                        actualHeight = size_.y;
                    }
                }
            } else {
                if (display_ !is null) {
                    if (DisplayImpl_X11 display2 = cast(DisplayImpl_X11)display_) {
                        actualX += display2.x;
                        actualY += display2.y;

                        if (actualWidth > display2.width)
                            actualWidth = display2.width;
                        if (actualHeight > display2.height)
                            actualHeight = display2.height;
                    }
                }
            }

            Window whandle;

            if (useOGLContext) {
                context = alloc.make!OpenGLContextImpl_X11(oglVersion, oglCallbacks);

                XVisualInfo* visualInfo = cast(XVisualInfo*)(cast(OpenGLContextImpl_X11)context).getPlatformData(this,
                        0);
                XSetWindowAttributes swa;
                Colormap cmap;

                cmap = x11.XCreateColormap(x11Display(), x11.XRootWindow(x11Display(),
                        visualInfo.screen), visualInfo.visual, AllocNone);
                swa.colormap = cmap;
                swa.background_pixmap = None;
                swa.border_pixel = 0;

                whandle = x11.XCreateWindow(x11Display(), parentWindow, actualX, actualY, actualWidth, actualHeight, 0,
                        visualInfo.depth, InputOutput, visualInfo.visual,
                        CWBorderPixel | CWColormap, &swa);
                (cast(OpenGLContextImpl_X11)context).setPlatformData(this, 0, &whandle);
            } else {
                whandle = x11.XCreateSimpleWindow(x11Display(), parentWindow, actualX, actualY, actualWidth,
                        actualHeight, 0, 0, x11.XWhitePixel(x11Display(), screenNum));
            }

            assert(whandle != 0);

            if (x11.XSetWMProtocols !is null) {
                Atom closeAtom = x11Atoms().WM_DELETE_WINDOW;
                if (closeAtom != 0) {
                    x11.XSetWMProtocols(x11Display(), whandle, &closeAtom, 1);
                }
            }

            if (useVRAMContext) {
                context = alloc.make!VRAMContextImpl_X11(whandle, vramWithAlpha, alloc);
            } else if (customContext !is null) {
                context = alloc.make!CustomContext(customContext);
            }

            ret = alloc.make!WindowImpl_X11(whandle, context, alloc, true);

            if (customContext !is null)
                (cast(CustomContext)context).init(ret);

            if (icon !is null)
                ret.setIcon(icon);

            if (cursorStyle == WindowCursorStyle.Custom)
                ret.setCustomCursor(cursorIcon, customIconHotspot);
            else
                ret.setCursor(cursorStyle);

            if (shouldAutoLockCursor)
                ret.lockCursorToWindow;

            if (ret.__getFeatureStyle !is null)
                ret.setStyle(windowStyle);

            ret.eventMasks = ExposureMask | StructureNotifyMask | FocusChangeMask | KeyReleaseMask |
                KeyPressMask | ButtonReleaseMask | ButtonPressMask | PointerMotionMask;
            x11.XSelectInput(x11Display(), whandle, ret.eventMasks);
            x11.XFlush(x11Display());

            return managed!IWindow(ret, managers(), alloc);
        }

        Feature_Icon __getFeatureIcon() {
            return this;
        }

        Feature_Cursor __getFeatureCursor() {
            return this;
        }

        @property {
            ImageStorage!RGBA8 getIcon() {
                return icon;
            }

            void setIcon(ImageStorage!RGBA8 v) {
                icon = v;
            }
        }

        void setCursor(WindowCursorStyle v) {
            cursorStyle = v;
        }

        WindowCursorStyle getCursor() {
            return cursorStyle;
        }

        void setCustomCursor(scope ImageStorage!RGBA8 v, vec2!ushort v2) {
            import devisualization.image.storage.base : ImageStorageHorizontal;
            import devisualization.image.interfaces : imageObjectFrom;

            if (cursorIcon !is null)
                alloc.dispose(cursorIcon);

            cursorStyle = WindowCursorStyle.Custom;
            cursorIcon = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(v, alloc);
            customIconHotspot = v2;
        }

        ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
            import devisualization.image.storage.base : ImageStorageHorizontal;
            import devisualization.image.interfaces : imageObjectFrom;

            return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(cursorIcon, alloc);
        }

        bool lockCursorToWindow() {
            shouldAutoLockCursor = true;
            return true;
        }

        void unlockCursorFromWindow() {
            shouldAutoLockCursor = false;
        }

        Feature_Style __getFeatureStyle() {
            return this;
        }

        void setStyle(WindowStyle style) {
            windowStyle = style;
        }

        WindowStyle getStyle() {
            return windowStyle;
        }

        void assignVRamContext(bool withAlpha = false) {
            useVRAMContext = true;
            useOGLContext = false;
            vramWithAlpha = withAlpha;
        }

        void assignOpenGLContext(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
            useOGLContext = true;
            useVRAMContext = false;

            oglVersion = version_;
            oglCallbacks = callbacks;
        }
    }
