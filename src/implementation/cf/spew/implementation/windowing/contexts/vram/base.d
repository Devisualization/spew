module cf.spew.implementation.windowing.contexts.vram.base;
import cf.spew.ui.context.features.vram;
import cf.spew.ui.context.defs;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8, RGBA8;

abstract class VRAMContextImpl : IContext, Have_VRam, Feature_VRam {
    Feature_VRam __getFeatureVRam() {
        return this;
    }

    abstract {
        @property {
            ImageStorage!RGB8 vramBuffer();
            ImageStorage!RGBA8 vramAlphaBuffer();
        }

        void activate();
        void deactivate();
        bool readyToBeUsed();
    }
}
