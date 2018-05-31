/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.context.defs;
import cf.spew.ui.rendering : IRenderPointCreator;

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

	/**
	 * Is the current context ready to be used?
	 */
	bool readyToBeUsed();
}

/**
 * Enables platform specific data hooking
 */
interface IPlatformData {
    ///
    bool supportsPlatformData(IRenderPointCreator renderPointCreator, int);
    ///
    void* getPlatformData(IRenderPointCreator renderPointCreator, int);
    ///
    void setPlatformData(IRenderPointCreator renderPointCreator, int, void*);
}
