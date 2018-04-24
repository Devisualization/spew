/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.display.defs;

/**
 * Represents a display.
 */
interface IDisplay {
	import cf.spew.ui.window.defs : IWindow;
	import devisualization.util.core.memory.managed;
	import stdx.allocator : IAllocator;

	private import cf.spew.ui.rendering : vec2;

	@property {
		/**
		 * The name of the display.
		 * This could be a computed name that is not meant for human consumption.
		 *
		 * Returns:
		 *      The name of the display.
		 */
		managed!string name();
		
		/**
		 * The dimensions of the display.
		 *
		 * Returns:
		 *      The dimensions (width/height) of the display.
		 */
		vec2!ushort size();

		/**
		 * The rate the monitor/display can refresh its contents.
		 * 
		 * Commonly this is 50 or 60.
		 *
		 * Returns:
		 *      The rate the monitor and display can refresh its contents.
		 */
		uint refreshRate();
		
		/**
		 * How bright the display is.
		 *
		 * Potentially a very expensive operation.
		 * Perform only when you absolutely need to.
		 *
		 * The default value is 10 and should be considered normal.
		 *
		 * Returns:
		 *      The brightness of the screen in lumens.
		 */
		uint luminosity();
		
		/**
		 * Is this display the primary monitor?
		 * 
		 * If it is not gainable and there is only one display
		 *  it will return true; otherwise false.
		 * 
		 * Returns:
		 * 		If this display is the primary one.
		 */
		bool isPrimary();
		
		/**
		 * How bright the display is.
		 * For usage with gamma display algorithms.
		 * 
		 * Potentially a very expensive operation.
		 * Perform only when you absolutely need to.
		 *
		 * The default value is 1 and should be considered normal.
		 * It will usually be between 0 and 2.
		 *
		 * Returns:
		 *      The brightness of the display.
		 */
		final float gamma() {
			return luminosity() / 10f;
		}
		
		/**
		 * All the windows on this display.
		 *
		 * Not all IDisplay's will support this.
		 * It is semi-optional.
		 *
		 * Returns:
		 *      All the windows on this display or null if none.
		 */
		managed!(IWindow[]) windows();
		
		/// No touchy, very dangerous!
		size_t __handle();
	}

	///
	IDisplay dup(IAllocator alloc);
}
