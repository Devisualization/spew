/**
 * Overlay windows for use with context menus or UI's for games.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.features.overlay;
//import cf.spew.ui.context.features.opengl : OpenGLVersion;
import cf.spew.ui.window.defs;
import std.experimental.memory.managed;

interface Have_OverlayWindow {
	Feature_OverlayWindow __getFeatureOverlayWindow();
}

interface Have_OverlayedWindows {
	IWindow[] windows();
	IWindowCreator[] deferredWindowsCreation();
}

interface Feature_OverlayWindow {
	void addOverlayWindow(OverlayWindowFeature feature, ubyte count=1, bool deferred=false);
	//void assignOpenGLContext(OpenGLVersion version_);
	void assignVRamContext(bool withAlpha=true);
}

///
enum OverlayWindowFeature {
	/// No behaviour, you're in control
	None,
	/// Bind to the size + location of the parent, for use as overlays in a game
	BindToParent,
	/// Binds to a location on the parent, for use for context menus
	BindToAParentLocation,
}

/**
 * Adds overlays that are owned for the given program.
 * They do not have decoration and are not closable by the user.
 * 
 * Params:
 *   self = context object
 *   feature = The core feature this overlay will have
 *   count = How many to create
 *   deferred = Should this be created now or later? (Can be used for other threads)
 */
void addOverlayWindow(IWindowCreator self, OverlayWindowFeature feature, ubyte count=1, bool deferred=false) {
	if (self.capableOfOverlayWindow)
		(cast(Have_OverlayWindow)self).__getFeatureOverlayWindow().addOverlayWindow(feature, count, deferred);
}

///
@property {
	/// Created overlayed windows
	managed!(IWindow[]) overlayWindows(IWindow self) {
		if (!self.capableOfOverlayWindow)
			return (managed!(IWindow[])).init;
		else {
			auto ret = (cast(Have_OverlayedWindows)self).windows;
			return managed!(IWindow[])(ret, managers(), Ownership.Secondary, self.allocator);
		}
	}

	/// Window creators for deferred creation of overlayed windows
	managed!(IWindowCreator[]) deferredWindowsCreation(IWindow self) {
		if (!self.capableOfOverlayWindow)
			return (managed!(IWindowCreator[])).init;
		else {
			auto ret = (cast(Have_OverlayedWindows)self).deferredWindowsCreation;
			return managed!(IWindowCreator[])(ret, managers(), Ownership.Secondary, self.allocator);
		}
	}
}

///
bool capableOfOverlayWindow(T)(T self) if (is(T : IWindowCreator)) {
	if (self is null)
		return false;
	else if (auto ss = cast(Have_OverlayWindow)self)
		return ss.__getFeatureOverlayWindow() !is null;
	else
		return false;
}

///
bool capableOfOverlayWindow(T)(T self) if (is(T : IWindow)) {
	if (self is null)
		return false;
	else if (auto ss = cast(Have_OverlayedWindows)self)
		return ss.windows() !is null;
	else
		return false;
}

bool capableOfOverlayWindow(T)(T self) if (!(is(T : IWindow) || is(T : IWindowCreator))) {
	static assert(0, "I do not know how to handle " ~ T.stringof ~ " I can only use IWindow, IWindowCreator types.");
}