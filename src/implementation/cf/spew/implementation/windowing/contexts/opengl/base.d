module cf.spew.implementation.windowing.contexts.opengl.base;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features.opengl;

abstract class OpenGLContextImpl : IContext, Have_OpenGL, Feature_OpenGL {
    package(cf.spew.implementation) {
        OpenGLVersion version_;
        OpenGL_Context_Callbacks* callbacks;
    }

    this(OpenGLVersion version_, OpenGL_Context_Callbacks* callbacks) {
        this.version_ = version_;
        this.callbacks = callbacks;
    }

    Feature_OpenGL __getFeatureOpenGL() {
        return this;
    }

    abstract {
        bool readyToBeUsed();
        void activate();
        void deactivate();
    }
}
