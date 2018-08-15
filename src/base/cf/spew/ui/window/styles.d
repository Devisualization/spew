/**
 * Styles for a window.
 *
 * These are very commonly supported feature set.
 * They should not be considered optional for most targets.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.styles;
import cf.spew.ui.window.defs;
import devisualization.util.core.memory.managed;

/**
 * A style a window can have
 * Enables usage for fullscreen and non resizable
 */
enum WindowStyle {
    ///
    Unknown,

    /**
     * Useful for e.g. context menus, menus, splash screens
     * No top bar, non-resizable, non-moveable, no-decorations
     */
    NoDecorations,

    /**
     * The default style of any window.
     * Close/Minimize/Maximize, resizable, moveable
     */
    Dialog,

    /**
     * Useful for tool boxes and such
     * Close/Minimize, non-resizable, moveable
     */
    Borderless,

    /**
     * Useful for e.g. message/input boxes
     * Close/Minimize, non-resizable, moveable, top most window
     */
    Popup,

    /**
     * Useful for e.g. 3d games
     * No top bar, non-resiable, non-moveable
     */
    Fullscreen
}

interface Have_Style {
    Feature_Style __getFeatureStyle();
}

interface Feature_Style {
    void setStyle(WindowStyle);
    WindowStyle getStyle();
}

@property {
    /**
     * Gets the style of the window
     *
     * Params:
     * 		self	=	The window[creator] instance
     *
     * Returns:
     *      The window style or unknown
     */
    WindowStyle style(T)(T self) if (is(T : IWindow) || is(T : IWindowCreator)) {
        if (self.capableOfWindowStyles) {
            return (cast(managed!Have_Style)self).__getFeatureStyle().getStyle();
        } else
            return WindowStyle.Unknown;
    }

    /**
     * Sets the window[creator] style
     *
     * Params:
     * 		self	=	The window[creator] instance
     * 		to		=	The style to set to
     */
    void style(T)(T self, WindowStyle to) if (is(T : IWindow) || is(T : IWindowCreator)) {
        if (self.capableOfWindowStyles) {
            (cast(managed!Have_Style)self).__getFeatureStyle().setStyle(to);
        }
    }

    /**
     * Does the given window[creator] support styles?
     *
     * Params:
     * 		self	=	The window[creator] instance
     *
     * Returns:
     * 		If the window[creator] supports having a style
     */
    bool capableOfWindowStyles(T)(T self) if (is(T : IWindow) || is(T : IWindowCreator)) {
        if (self is null)
            return false;
        else {
            auto ss = cast(managed!Have_Style)self;
            return ss !is null && ss.__getFeatureStyle() !is null;
        }
    }
}
