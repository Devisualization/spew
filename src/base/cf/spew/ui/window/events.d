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

///
alias EventOnRequestCloseDel = bool delegate();
///
alias EventOnRequestCloseFunc = bool function();

/**
 * Group of hookable events for rendering upon
 */
interface IWindowEvents : IRenderEvents {
	import std.functional : toDelegate;
	
	@property {
		/**
		 * When the window has been moved this event will be triggered.
		 *
		 * Params:
		 *      del     =   The callback to call
		 */
		void onMove(EventOnMoveDel del);
		
		/// Ditto
		final void onMove(EventOnMoveFunc func) { onMove(func.toDelegate); }

		/**
		 * When the window has had a request for the window to close (x button), this event will be triggered.
		 * 
		 * Params:
		 *      del     =   The callback to call
		 */
		void onRequestClose(EventOnRequestCloseDel del);

		/// Ditto
		final void onRequestClose(EventOnRequestCloseFunc func) { onRequestClose(func.toDelegate); }

		/**
		 * When the key is pressed, the callback is called.
		 *
		 * Params:
		 *      del     =   The callback to call
		 */
		void onKeyPress(EventOnKeyDel del);

		/// Ditto
		final void onKeyPress(EventOnKeyFunc func) { onKeyPress(func.toDelegate); }

		/**
		 * When the key is released, the callback is called.
		 *
		 * Params:
		 *      del     =   The callback to call
		 */
		void onKeyRelease(EventOnKeyDel del);
		
		/// Ditto
		final void onKeyRelease(EventOnKeyFunc func) { onKeyRelease(func.toDelegate); }
	}
}