///
module cf.spew.ui.context.defs;

/**
 * A basic representation of a context to be rendered to.
 */
interface IContext {
	/**
	 * Makes the context drawable.
	 */
	void activate();

	/**
	 * Deactivates the context from being able to draw.
	 * 
	 * If double buffering is supported, this will perform a buffer swap.
	 * On top of the rendering.
	 */
	void deactivate();
}