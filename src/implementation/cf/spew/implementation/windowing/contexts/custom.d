module cf.spew.implementation.windowing.contexts.custom;
import cf.spew.ui.rendering;
import cf.spew.ui.context.defs;
import cf.spew.ui.context.features.custom;
import devisualization.util.core.memory.managed;

final class CustomContext : IContext {
    private managed!ICustomContext context_;

    this(managed!ICustomContext ctx) {
        context_ = ctx;
    }

    void init(IRenderPoint rp) {
        context_.initialize(rp);
    }

    void activate() {
        context_.activate();
    }

    void deactivate() {
        context_.deactivate();
    }

    bool readyToBeUsed() {
        return context_.readyToBeUsed();
    }
}
