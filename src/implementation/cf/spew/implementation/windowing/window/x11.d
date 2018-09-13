module cf.spew.implementation.windowing.window.x11;
version(Posix):
import cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.windowing.display.x11;
import cf.spew.implementation.windowing.utilities.x11;
import cf.spew.implementation.instance.ui.x11;
import cf.spew.implementation.instance.ui.notifications_sdbus : SDBus_KDENotifications;
import cf.spew.implementation.instance.state : uiInstance, taskbarTrayWindow;
import cf.spew.ui.window.features.cursor;
import cf.spew.ui.window.features.icon;
import cf.spew.ui.window.features.screenshot;
import cf.spew.ui.window.styles;
import cf.spew.event_loop.wells.x11;
import cf.spew.ui.context.defs;
import cf.spew.ui.display.defs;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.events : EventOnFileDropDel;
import devisualization.bindings.x11;
import devisualization.util.core.memory.managed;
import devisualization.image : ImageStorage, imageObjectFrom, ImageStorageHorizontal;
import stdx.allocator : IAllocator, make, makeArray, dispose;
import std.experimental.color : RGBA8, RGB8;
import std.traits : isSomeString;
import std.utf : codeLength, byDchar, byChar;
import core.stdc.config : c_ulong;

final class WindowImpl_X11 : WindowImpl,
    Feature_Window_ScreenShot, Feature_Icon, Feature_Cursor, Feature_Style,
Have_Window_ScreenShot, Have_Icon, Have_Cursor, Have_Style {
    
    bool isClosed, supportsXDND, stateOfVisibleCall;
    Window whandle;
    XIC xic;
    
    Atom xdndToBeRequested;
    Window xdndSourceWindow;
    
    uint eventMasks;
    WindowStyle wstyle;
    
    Cursor currentCursor = None;
    WindowCursorStyle cursorStyle;
    ImageStorage!RGBA8 customCursor;
    XcursorImage* customCursorImage;
    
    int lastX, lastY;
    int lastWidth, lastHeight;
    
    this(Window handle, IContext context, IAllocator alloc, bool processOwns=false) {
        this.whandle = handle;
        this.alloc = alloc;
        this.context_ = context;
        
        super(processOwns);
        
        xic = x11.XCreateIC(x11XIM(),
            XNInputStyle.ptr, XIMPreeditNothing | XIMStatusNothing,
            XNClientWindow.ptr, whandle,
            XNFocusWindow.ptr, whandle, 0);
        
        if (x11Atoms().XdndAware != None) {
            supportsXDND  = true;
            Atom version_ = 5;
            x11.XChangeProperty(x11Display(), whandle, x11Atoms().XdndAware, x11Atoms().XA_ATOM, 32, PropModeReplace, cast(ubyte*)&version_, 1);
        }
    }
    
    ~this() {
        if (context_ !is null)
            alloc.dispose(context_);
        close();
    }

    override IContext context() {
        if (!visible || isClosed) return null;
        return context_;
    }
    
    @property {
        vec2!uint size() {
            if (!visible || isClosed) return vec2!uint.init;
            auto att = x11WindowAttributes(whandle);
            return vec2!uint(att.width, att.height);
        }
        
        managed!IDisplay display() {
            import std.algorithm : max, min;
            IDisplay theDisplay;
            int numMonitors;
            XRRMonitorInfo* monitors = x11.XRRGetMonitors(x11Display(), whandle, true, &numMonitors);
            
            if (numMonitors == -1)
                return managed!(IDisplay).init;
            
            XRRMonitorInfo theMonitor;
            auto att = x11WindowAttributes(whandle);
            int x2 = att.x + att.width, y2 = att.y + att.height;
            int lastOverlap;
            
            foreach(i; 0 .. numMonitors) {
                int x1 = monitors[i].x + monitors[i].width, y1 = monitors[i].x + monitors[i].y;
                int xOverlap = max(0, min(x2, x1) - max(att.x, monitors[i].x));
                int yOverlap = max(0, min(y2, y1) - max(att.y, monitors[i].y));
                int overlap = xOverlap * yOverlap;
                
                if (overlap > lastOverlap) {
                    lastOverlap = overlap;
                    theMonitor = monitors[i];
                }
            }
            
            x11.XRRFreeMonitors(monitors);
            return managed!IDisplay(alloc.make!DisplayImpl_X11(att.screen, &theMonitor, alloc), managers(ReferenceCountedManager()), alloc);
        }
        
        bool renderable() {
            if (isClosed) return false;
            auto att = x11WindowAttributes(whandle);
            return (att.map_state & IsViewable) == IsViewable;
        }
        
        size_t __handle() { return cast(size_t)whandle; }
        
        override void onFileDrop(EventOnFileDropDel del) { onFileDropDel = del; }
    }
    
    void close() {
        if (isClosed) return;
        
        if (xic !is null) {
            x11.XDestroyIC(xic);
            xic = null;
        }
        
        hide();
        x11.XDestroyWindow(x11Display(), whandle);
        
        if (currentCursor != None)
            x11.XFreeCursor(x11Display(), currentCursor);
        if (customCursorImage !is null) // ugh are these needed?
            x11.XcursorImageDestroy(customCursorImage);
        
        isClosed = true;
        x11.XFlush(x11Display());
    }
    
    @property {
        managed!dstring title() {
            import core.stdc.string : strlen;
            
            char* temp;
            char[] buffer = temp[0 .. strlen(temp)];
            x11.XFetchName(x11Display(), whandle, &temp);
            
            // what is allocated could potentially be _more_ then required
            dchar[] buffer2 = alloc.makeArray!dchar(codeLength!char(buffer));
            
            size_t i;
            foreach(c; buffer.byDchar) {
                buffer2[i] = c;
                i++;
            }
            
            alloc.dispose(buffer);
            x11.XFree(temp);
            return managed!dstring(cast(dstring)buffer2, managers(), alloc);
        }
        
        void title(string text) { setTitle(text); }
        void title(wstring text) { setTitle(text); }
        void title(dstring text) { setTitle(text); }
        
        void setTitle(String)(String text) if (isSomeString!String) {
            // if this ends in segfaults, switch to malloc and don't free.
            // xlib will free.
            
            char[] temp = alloc.makeArray!char(codeLength!char(text) + 1);
            temp[$-1] = 0;
            
            size_t i;
            foreach(c; text.byChar) {
                temp[i] = c;
                i++;
            }
            
            x11.XStoreName(x11Display(), whandle, temp.ptr);
            alloc.dispose(temp);
        }
        
        void location(vec2!int point) {
            if (isClosed) return;
            x11.XMoveWindow(x11Display(), whandle, point.x, point.y);
            x11.XFlush(x11Display());
        }
        
        vec2!int location() {
            if (isClosed) return vec2!int.init;
            auto att = x11WindowAttributes(whandle);
            return vec2!int(att.x, att.y);
        }
        
        void size(vec2!uint point) {
            if (isClosed) return;
            x11.XResizeWindow(x11Display(), whandle, point.x, point.y);
            x11.XFlush(x11Display());
        }
    }
    
    void hide() {
        if (isClosed) return;
        x11.XUnmapWindow(x11Display(), whandle);
        x11.XFlush(x11Display());
    }
    
    void show() {
        if (isClosed) return;
        x11.XMapWindow(x11Display(), whandle);
        x11.XFlush(x11Display());
    }
    
    Feature_Window_ScreenShot __getFeatureScreenShot() {
        if (isClosed) return null;
        return this;
    }
    
    ImageStorage!RGB8 screenshot(IAllocator alloc=null) {
        if (isClosed) return null;
        
        import devisualization.image : ImageStorage;
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObject;
        import std.experimental.color : RGB8, RGBA8;
        
        if (alloc is null)
            alloc = this.alloc;
        
        auto theSize = size();
        XImage* complete = x11.XGetImage(x11Display(), cast(Drawable)whandle, 0, 0, theSize.x, theSize.y, AllPlanes, ZPixmap);
        auto storage = imageObject!(ImageStorageHorizontal!RGB8)(theSize.x, theSize.y, alloc);
        
        foreach(y; 0 .. theSize.y) {
            foreach(x; 0 .. theSize.x) {
                auto pix = x11.XGetPixel(complete, x, y);
                storage[x, y] = RGB8(cast(ubyte)((pix & complete.red_mask) >> 16), cast(ubyte)((pix & complete.green_mask) >> 8), cast(ubyte)(pix & complete.blue_mask));
            }
        }
        
        x11.XFree(complete);
        return storage;
    }
    
    Feature_Icon __getFeatureIcon() {
        if (isClosed) return null;
        return this;
    }
    
    ImageStorage!RGBA8 getIcon() @property {
        import devisualization.image : ImageStorage;
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObject;
        import std.experimental.color : RGB8, RGBA8;
        
        Atom net_wm_icon = x11Atoms()._NET_WM_ICON;
        Atom cardinal = x11Atoms().CARDINAL;

        X11WindowProperty prop = x11ReadWindowProperty(x11Display(), whandle, net_wm_icon);
        scope(exit) if (prop.data !is null) x11.XFree(prop.data);
        
        if (prop.format == 32 && prop.type == cardinal && prop.data !is null && prop.numberOfItems > 2) {
            // great same, we can use this!
            
            c_ulong* source = cast(c_ulong*)prop.data;
            uint width = cast(uint)source[0];
            uint height = cast(uint)source[1];
            
            if ((width*height)+2 != prop.numberOfItems)
                return null;
            
            auto storage = imageObject!(ImageStorageHorizontal!RGBA8)(width, height, alloc);
            size_t offset=2;
            
            foreach(y; 0 .. height) {
                foreach(x; 0 .. width) {
                    auto p = source[offset++];
                    storage[x, y] = RGBA8((cast(ubyte)(p >> 16)), (cast(ubyte)(p >> 8)), (cast(ubyte)p), (cast(ubyte)(p >> 24)));
                }
            }

            return storage;
        } else
            return null;
    }
    
    void setIcon(ImageStorage!RGBA8 from) @property {
        import core.stdc.stdlib : malloc;
        
        assert(from.width <= uint.max);
        assert(from.height <= uint.max);
        
        int numItems = cast(int)(from.width*from.height);
        c_ulong[] imageData = (cast(c_ulong*)malloc(c_ulong.sizeof*(numItems+2)))[0 .. numItems+2];
        size_t offset;
        
        imageData[offset++] = cast(uint)from.width;
        imageData[offset++] = cast(uint)from.height;
        
        foreach(y; 0 .. from.height) {
            foreach(x; 0 .. from.width) {
                auto p = from[x, y];
                imageData[offset++] = p.b.value | (p.g.value << 8) | (p.r.value << 16) | (p.a.value << 24);
            }
        }

        if (shared(FreeDesktopNotifications) fdn = cast(shared(FreeDesktopNotifications))uiInstance.__getFeatureNotificationTray()) {
            if (fdn.haveNotificationWindow() && (cast()taskbarTrayWindow).__handle == whandle) {
                uint[] imageData2 = (cast(uint*)malloc(4*numItems))[0 .. numItems];
                foreach(i, o; imageData[2 .. numItems+2])
                    imageData2[i] = cast(uint)imageData[i+2];

                fdn.drawSystray(cast(uint)from.width, cast(uint)from.height, imageData2.ptr);
            }
        } else if (shared(SDBus_KDENotifications) kden = cast(shared(SDBus_KDENotifications))uiInstance.__getFeatureNotificationTray()) {
            if (kden.haveNotificationWindow() && (cast()taskbarTrayWindow).__handle == whandle) {
                kden.prepareNewIcon(from);
            }
        }
        
        Atom net_wm_icon = x11Atoms()._NET_WM_ICON;
        Atom cardinal = x11Atoms().CARDINAL;
        x11.XChangeProperty(x11Display(), whandle, net_wm_icon, cardinal, 32, PropModeReplace, cast(ubyte*)imageData.ptr, numItems+2);
    }
    
    Feature_Cursor __getFeatureCursor() {
        if (isClosed) return null;
        return this;
    }
    
    void setCursor(WindowCursorStyle style) {
        if (isClosed) return;
        assert(cursorStyle != WindowCursorStyle.Indeterminate);
        
        // unload systemy stuff
        if (currentCursor != None)
            x11.XFreeCursor(x11Display(), currentCursor);
        if (customCursorImage !is null) // ugh are these needed?
            x11.XcursorImageDestroy(customCursorImage);
        
        cursorStyle = style;
        
        if (style != WindowCursorStyle.Custom) {
            // load up reference to system one
            
            switch(style) {
                case WindowCursorStyle.Busy:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_watch);
                    break;
                case WindowCursorStyle.Hand:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_hand1);
                    break;
                case WindowCursorStyle.NoAction:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_X_cursor);
                    break;
                case WindowCursorStyle.ResizeCornerTopLeft:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_left_corner);
                    break;
                case WindowCursorStyle.ResizeCornerTopRight:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_right_corner);
                    break;
                case WindowCursorStyle.ResizeCornerBottomLeft:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_left_corner);
                    break;
                case WindowCursorStyle.ResizeCornerBottomRight:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_right_corner);
                    break;
                    
                case WindowCursorStyle.ResizeLeftHorizontal:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_left_side);
                    break;
                case WindowCursorStyle.ResizeTopVertical:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_top_side);
                    break;
                case WindowCursorStyle.ResizeRightHorizontal:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_right_side);
                    break;
                case WindowCursorStyle.ResizeBottomVertical:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_bottom_side);
                    break;
                    
                case WindowCursorStyle.TextEdit:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_xterm);
                    break;
                    
                case WindowCursorStyle.None:
                    currentCursor = None;
                    break;
                case WindowCursorStyle.Standard:
                default:
                    currentCursor = x11.XCreateFontCursor(x11Display(), XC_left_ptr);
                    break;
            }
            
            XSetWindowAttributes attr;
            attr.cursor = currentCursor;
            x11.XChangeWindowAttributes(x11Display(), whandle, CWCursor, &attr);
        }
    }
    
    WindowCursorStyle getCursor() { return cursorStyle; }
    
    void setCustomCursor(scope ImageStorage!RGBA8 image, vec2!ushort hotspot) {
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObjectFrom;
        
        if (image is null) return;
        assert(cursorStyle != WindowCursorStyle.Indeterminate);
        
        if (x11.XcursorImageCreate !is null && x11.XcursorImageLoadCursor !is null && x11.XcursorImageDestroy !is null &&
            x11.XcursorSupportsARGB !is null && x11.XcursorSupportsARGB(x11Display()) == XcursorTrue) {
            
            if (currentCursor != None)
                x11.XFreeCursor(x11Display(), currentCursor);
            if (customCursorImage !is null)
                x11.XcursorImageDestroy(customCursorImage);
            
            // The comments here specify the preferred way to do this.
            // Unfortunately at the time of writing, it is not possible to
            //  use devisualization.image for resizing.
            
            setCursor(WindowCursorStyle.Custom);
            
            // duplicate image, store
            customCursor = imageObjectFrom!(ImageStorageHorizontal!RGBA8)(image, alloc);
            
            customCursorImage = x11.XcursorImageCreate(cast(int)image.width, cast(int)image.height);
            customCursorImage.xhot = hotspot.x;
            customCursorImage.yhot = hotspot.y;
            
            size_t offset;
            foreach(y; 0 .. image.height) {
                foreach(x; 0 .. image.width) {
                    auto p = image[x, y];
                    customCursorImage.pixels[offset++] = p.b.value | (p.g.value << 8) | (p.r.value << 16) | (p.a.value << 24);
                }
            }
            
            currentCursor = x11.XcursorImageLoadCursor(x11Display(), customCursorImage);
        }
    }
    
    ImageStorage!RGBA8 getCursorIcon(IAllocator alloc) {
        import devisualization.image.storage.base : ImageStorageHorizontal;
        import devisualization.image.interfaces : imageObjectFrom;
        return imageObjectFrom!(ImageStorageHorizontal!RGBA8)(customCursor, alloc);
    }
    
    bool lockCursorToWindow() {
        // if this fails, we'll just have to return false :/
        auto ret = x11.XGrabPointer(x11Display(), whandle, false,
            ~(ExposureMask | KeyPressMask | KeyReleaseMask) & eventMasks, GrabModeAsync, GrabModeAsync, whandle, currentCursor, CurrentTime);
        return ret == GrabSuccess;
    }
    
    void unlockCursorFromWindow() {
        x11.XUngrabPointer(x11Display(), CurrentTime);
    }
    
    Feature_Style __getFeatureStyle() { return isClosed ? null : this; }
    
    void setStyle(WindowStyle style) {
        wstyle = style;
        
        bool noResize;
        Motif_WMHints motifWmHints;
        
        Atom windowType = x11Atoms()._NET_WM_WINDOW_TYPE_NORMAL;
        Atom[10] wmAllowedActions, wmState;
        uint wmAllowedActionsCount, wmStateCount;
        
        switch(style) {
            case WindowStyle.NoDecorations:
                noResize = true;
                motifWmHints = WindowX11Styles.NoDecorations;
                
                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_STICKY;
                break;
                
            case WindowStyle.Fullscreen:
                motifWmHints = WindowX11Styles.Fullscreen;
                
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_FULLSCREEN;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_ABOVE;
                
                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_FULLSCREEN;
                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_ABOVE;
                
                // reset size hints in case already set
                
                XSizeHints sizeHints;
                sizeHints.flags = PMinSize | PMaxSize;
                
                sizeHints.min_width = 0;
                sizeHints.max_width = int.max;
                sizeHints.min_height = 0;
                sizeHints.max_height = int.max;
                
                x11.XSetWMNormalHints(x11Display(), whandle, &sizeHints);
                break;
                
            case WindowStyle.Popup:
                noResize = true;
                motifWmHints = WindowX11Styles.Popup;
                windowType = x11Atoms()._NET_WM_STATE_MODAL;
                
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_ABOVE;
                
                wmState[wmStateCount++] = x11Atoms()._NET_WM_STATE_ABOVE;
                break;
                
            case WindowStyle.Borderless:
                noResize = true;
                motifWmHints = WindowX11Styles.Borderless;
                windowType = x11Atoms()._NET_WM_WINDOW_TYPE_UTILITY;
                
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                break;
                
            case WindowStyle.Dialog:
            default:
                motifWmHints = WindowX11Styles.Dialog;
                
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MOVE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_RESIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_CLOSE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MINIMIZE;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MAXIMIZE_HORZ;
                wmAllowedActions[wmAllowedActionsCount++] = x11Atoms()._NET_WM_ACTION_MAXIMIZE_VERT;
                break;
        }
        
        auto currentwAttributes = x11WindowAttributes(whandle);
        lastWidth = currentwAttributes.width;
        lastHeight = currentwAttributes.height;
        
        // sets WM_NORMAL_HINTS
        if (noResize) {
            XSizeHints sizeHints;
            sizeHints.flags = PMinSize | PMaxSize;
            
            sizeHints.min_width = lastWidth;
            sizeHints.max_width = lastWidth;
            sizeHints.min_height = lastHeight;
            sizeHints.max_height = lastHeight;
            
            x11.XSetWMNormalHints(x11Display(), whandle, &sizeHints);
        }
        
        // first up we /try/ to setup window hints using motif as a fallback
        Atom motifWindowHintsAtom = x11Atoms()._MOTIF_WM_HINTS;
        if (motifWindowHintsAtom != None)
            x11.XChangeProperty(x11Display(), whandle, motifWindowHintsAtom, motifWindowHintsAtom, 32, PropModeReplace, cast(ubyte*)&motifWmHints, 5);
        
        Atom xaAtom = x11Atoms().XA_ATOM;
        if (xaAtom != None) {
            // apply _NET_WM_ALLOWED_ACTIONS
            Atom wmAllowedActionsAtom = x11Atoms()._NET_WM_ALLOWED_ACTIONS;
            if (wmAllowedActionsAtom != None)
                x11.XChangeProperty(x11Display(), whandle, wmAllowedActionsAtom, xaAtom, 32, PropModeReplace, cast(ubyte*)wmAllowedActions.ptr, wmAllowedActionsCount);
            
            // apply _NET_WM_STATE
            Atom wmStateAtom = x11Atoms()._NET_WM_STATE;
            if (wmStateAtom != None)
                x11.XChangeProperty(x11Display(), whandle, wmStateAtom, xaAtom, 32, PropModeReplace, cast(ubyte*)wmState.ptr, wmStateCount);
        }
        
        // full screen requires further special behavior
        // which requires knowledge of the monitor itself
        if (style == WindowStyle.Fullscreen) {
            XEvent xev;
            xev.type = ClientMessage;
            xev.xclient.window = whandle;
            xev.xclient.message_type = x11Atoms()._NET_WM_STATE;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = 1;
            xev.xclient.data.l[1] = x11Atoms()._NET_WM_STATE_FULLSCREEN;
            xev.xclient.data.l[2] = 0;
            
            x11.XMapWindow(x11Display(), whandle);
            x11.XSendEvent(x11Display(), x11.XDefaultRootWindow(x11Display()), false, SubstructureRedirectMask | SubstructureNotifyMask, &xev);
        }
        
        x11.XFlush(x11Display());
    }
    
    WindowStyle getStyle() { return wstyle; }
}
