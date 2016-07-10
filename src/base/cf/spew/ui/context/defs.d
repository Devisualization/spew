module cf.spew.ui.context.defs;

/**
 * A basic representation of a context to be rendered to.
 */
interface IContext {
	/**
     * Swaps the buffers and makes the being drawn buffer to current.
     * Inherently meant for double buffering.
     */
	void swapBuffers();
}