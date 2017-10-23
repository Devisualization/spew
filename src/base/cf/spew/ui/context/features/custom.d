/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.context.features.custom;
import cf.spew.ui.context.defs;
import cf.spew.ui.rendering;
import devisualization.util.core.memory.managed;

interface Have_CustomCtx {
	void assignCustomContext(managed!ICustomContext);
}

///
interface ICustomContext : IContext {
	/**
	 * Beware, the render point probably isn't ready for calling.
	 * This just tells you the window id ext. which can be quite
	 *  unsafe if you don't read the source!
	 */
	void initialize(IRenderPoint);
}

/**
 * Tells the render point creator to set the context to be the custom one
 * If the platform does not support it, it will gracefully return.
 *
 * Params:
 *      self        =   The render point.
 *      customContext    =   The custom context to load into the window.
 */
void assignCustomContext(IRenderPointCreator self, managed!ICustomContext customContext) {
	if (self is null)
		return;
	if (Have_CustomCtx ss = cast(Have_CustomCtx)self) {
		ss.assignCustomContext(customContext);
	}
}