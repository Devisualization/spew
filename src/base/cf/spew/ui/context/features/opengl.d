///
module cf.spew.ui.context.features.opengl;
import cf.spew.ui.rendering;
import cf.spew.ui.context.defs;

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
	void delegate() onLoad;
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
void assignOpenGLContext(IRenderPointCreator self, OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
	if (self is null)
		return;
	if (Have_OGLCtx ss = cast(Have_OGLCtx)self) {
		ss.assignOpenGLContext(version_, callbacks);
	}
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