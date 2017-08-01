/**
 * Window screenshot capabilities.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.features.screenshot;
import cf.spew.ui.window.defs;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.allocator : IAllocator, theAllocator;
import std.experimental.graphic.color : RGB8;
import std.experimental.memory.managed;

interface Have_Window_ScreenShot {
	Feature_Window_ScreenShot __getFeatureScreenShot();
}

interface Feature_Window_ScreenShot {
	ImageStorage!RGB8 screenshot(IAllocator alloc=theAllocator());
}

@property {
    /// Takes a screenshot or null if not possible
	managed!(ImageStorage!RGB8) screenshot(scope IWindow self, IAllocator alloc=theAllocator()) {
		if (!self.capableOfScreenShot)
			return (managed!(ImageStorage!RGB8)).init;
		else {
			auto ret = (cast(Have_Window_ScreenShot)self).__getFeatureScreenShot().screenshot;
			return managed!(ImageStorage!RGB8)(ret, managers(), alloc);
		}
    }

	/**
	 * Can a screenshot be taken of window/display/platform?
	 * 
	 * Params:
	 * 		self	=	The window/display/platform instance
	 * 
	 * Returns:
	 * 		If the window/display/platform supports having a screenshot taken of it
	 */
	bool capableOfScreenShot(scope IWindow self) {
		if (self is null)
			return false;
		else if (auto ss = cast(Have_Window_ScreenShot)self)
			return ss.__getFeatureScreenShot() !is null;
		else
			return false;
	}
}
