/**
 * Events related to windows and render points
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.events;
import cf.spew.ui.events;

///
alias EventOnMoveDel = void delegate(int x, int y);
///
alias EventOnMoveFunc = void function(int x, int y);

/**
 * Group of hookable events for rendering upon
 */
interface IWindowEvents : IRenderEvents {
	import std.functional : toDelegate;
	
	@property {
		/**
         * When the window has been moved this event will triggered.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onMove(EventOnMoveDel del);
		
		/// Ditto
		final void onMove(EventOnMoveFunc func) { onMove(func.toDelegate); }

		// TODO: on key down + up
	}
}