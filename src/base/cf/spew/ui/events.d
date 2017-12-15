/**
 * Events related to windows and render points
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.events;
import cf.spew.events.windowing;

///
alias EventOnForcedDrawDel = void delegate();
///
alias EventOnForcedDrawFunc = void function();

///
alias EventOnCursorMoveDel = void delegate(int x, int y);
///
alias EventOnCursorMoveFunc = void function(int x, int y);

///
alias EventOnCursorActionDel = void delegate(CursorEventAction action);
///
alias EventOnCursorActionFunc = void function(CursorEventAction action);

///
alias EventOnScrollDel = void delegate(int amount);
///
alias EventOnScrollFunc = void function(int amount);

///
alias EventOnCloseDel = void delegate();
///
alias EventOnCloseFunc = void function();

///
alias EventOnKeyDel = void delegate(dchar key, SpecialKey specialKey, ushort KeyModifiers);
///
alias EventOnKeyFunc = void function(dchar key, SpecialKey specialKey, ushort KeyModifiers);

///
alias EventOnSizeChangeDel = void delegate(uint width, uint height);
///
alias EventOnSizeChangeFunc = void function(uint width, uint height);

///
alias EventOnFileDropDel = void delegate(scope string filename, int x, int y);
///
alias EventOnFileDropFunc = void function(scope string filename, int x, int y);


/**
 * Group of hookable events for rendering upon
 */
interface IRenderEvents {
	import std.functional : toDelegate;
	
	@property {
		/**
         * When the OS informs the program that the window must be redrawn
         *  this callback will be called.
         *
         * This could be because of movement, resizing of a window or 
         *  the computer has come out of hibernation.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onForcedDraw(EventOnForcedDrawDel del);
		
		/// Ditto
		final void onForcedDraw(EventOnForcedDrawFunc func) { onForcedDraw(func.toDelegate); }
		
		/**
         * When the cursor moves within the window the callback is called.
         *
         * Commonly this is will be a mouse.
         * The values passed will be relative to the render point.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onCursorMove(EventOnCursorMoveDel del);
		
		/// Ditto
		final void onCursorMove(EventOnCursorMoveFunc func) { onCursorMove(func.toDelegate); }
		
		/**
         * When an action associated with a cursor occurs, the callback is called.
         *
         * When the cursor is backed by a mouse:
         *  - The left mouse button will be mapped to Select
         *  - The right mouse button will be mapped to Alter
         *  - The middle mouse button will be mapped to ViewChange
         *
         * Params:
         *      del     =   The callback to call
         */
		void onCursorAction(EventOnCursorActionDel del);
		
		/// Ditto
		final void onCursorAction(EventOnCursorActionFunc func) { onCursorAction(func.toDelegate); }
		
		/**
         * When an action associated with a cursor no longer occurs, the callback is called.
         *
         * When the cursor is backed by a mouse:
         *  - The left mouse button will be mapped to Select
         *  - The right mouse button will be mapped to Alter
         *  - The middle mouse button will be mapped to ViewChange
         *
         * Params:
         *      del     =   The callback to call
         */
		void onCursorActionEnd(EventOnCursorActionDel del);
		
		/// Ditto
		final void onCursorActionEnd(EventOnCursorActionFunc func) { onCursorActionEnd(func.toDelegate); }
		
		/**
         * When a scroll event occurs the callback is called.
         *
         * Most of the time this is only implemented for mouses.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onScroll(EventOnScrollDel del);
		
		/// Ditto
		final void onScroll(EventOnScrollFunc func) { onScroll(func.toDelegate); }
		
		/**
         * Upon when render point is non renderable (final) the callback will be called. 
         *
         * If the render point is a window, this will not fire when it is minimized
         *  instead it will only fire when it no longer can be restored.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onClose(EventOnCloseDel del);
		
		/// Ditto
		final void onClose(EventOnCloseFunc func) { onClose(func.toDelegate); }
		
		/**
         * When the key is entered into the program, the callback is called.
         *
         * If this is backed by a keyboard it will fire on a key push.
         *
         * Params:
         *      del     =   The callback to call
         */
		void onKeyEntry(EventOnKeyDel del);
		
		/// Ditto
		final void onKeyEntry(EventOnKeyFunc func) { onKeyEntry(func.toDelegate); }

		/**
		 * When the render pointer size has changed.
		 * 
		 * Also triggered when the window client area's size has changed.
		 * 
		 * Params:
		 * 		del		=	The callback to call
		 */
		void onSizeChange(EventOnSizeChangeDel del);

		/// Ditto
		final void onSizeChange(EventOnSizeChangeFunc func) { onSizeChange(func.toDelegate); }

		/**
		 * When the window has had a file dragged on top of it, call this.
		 * 
		 * If this is not set, drag and drop will be disabled.
		 * 
		 * Params:
		 * 		del		=	The callback to call
		 */
		void onFileDrop(EventOnFileDropDel del);

		/// Ditto
		final void onFileDrop(EventOnFileDropFunc func) { onFileDrop(func.toDelegate); }
	}
}