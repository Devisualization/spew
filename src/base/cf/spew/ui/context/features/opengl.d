/**
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.context.features.opengl;
import cf.spew.ui.rendering;
import cf.spew.ui.context.defs;
import devisualization.util.core.memory.managed;

interface Have_OGLCtx {
	void assignOpenGLContext(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks);
}

///
struct OpenGLVersion {
	///
	ushort major;
	///
	ushort minor;
}

///
struct OpenGL_Context_Callbacks {
	///
	void delegate() onActivate;
	///
	void delegate() onDeactivate;

	/// On creation of the context
	void delegate(string platformPrefferedLoadFunction) onLoad;
	/// On preffered context e.g. non-legacy creation
	void delegate() onReload;
	///  On destruction of the context
	void delegate() onUnload;

	/// When the context is ready for you to load your symbols
	void delegate() onLoadOfSymbols;
	/// Enables the context to load a given symbol to call
	void* delegate(string name) loadSymbol;
}

/**
 * Tells the render point creator to set the context to be OpenGL.
 * If the platform does not support it, it will gracefully return.
 *
 * If callbacks is null, it will attempt to load any symbols required, however it will probably get it wrong and fail.
 *
 * Params:
 *      self        =   The render point.
 *      version_    =   What version of OpenGL should it attempt to use
 *      callbacks   =   Callbacks that modify how the context will operate e.g. loading of OpenGL functions
 */
void assignOpenGLContext(T)(managed!T self, OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) if (is(T : IRenderPointCreator) || is(T : IWindowCreator)) {
	if (self is null)
		return;
	auto ss = cast(managed!Have_OGLCtx)self;
	if (ss !is null)
		ss.assignOpenGLContext(version_, callbacks);
}

interface Have_OpenGL {
	Feature_OpenGL __getFeatureOpenGL();
}

interface Feature_OpenGL {}

@property {
	/**
	 * Does the given context support OpenGL for drawing?
	 * 
	 * Params:
	 * 		self	=	The platform instance
	 * 
	 * Returns:
	 * 		If the context supports drawing via OpenGL
	 */
	bool capableOfOpenGL(IContext self) {
		if (self is null)
			return false;
		else if (Have_OpenGL ss = cast(Have_OpenGL)self)
			return ss.__getFeatureOpenGL() !is null;
		else
			return false;
	}
}