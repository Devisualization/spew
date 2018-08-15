module cf.spew.implementation.windowing.window.base;
import cf.spew.implementation.instance.state : windowToIdMapper;
import cf.spew.ui.events;
import cf.spew.ui.window.defs;
import cf.spew.ui.window.events;
import cf.spew.ui.context.defs;
import std.datetime.stopwatch;
import stdx.allocator : IAllocator, make, makeArray, dispose;

abstract class WindowImpl : IWindow, IWindowEvents {
    IAllocator alloc;
    IContext context_;
    
    StopWatch notificationTraySW;
    bool ownedByProcess;
    
    EventOnCursorMoveDel onCursorMoveDel;
    EventOnCursorActionDel onCursorActionDel, onCursorActionEndDel;
    EventOnScrollDel onScrollDel;
    EventOnKeyDel onKeyEntryDel, onKeyPressDel, onKeyReleaseDel;
    EventOnSizeChangeDel onSizeChangeDel;
    EventOnMoveDel onMoveDel;
    
    EvenOnFileDragDel onFileDragStartDel, onFileDragStopDel;
    EventOnFileDropDel onFileDropDel;
    EventOnFileDraggingDel onFileDraggingDel;
    
    EventOnForcedDrawDel onDrawDel;
    EventOnCloseDel onCloseDel;
    EventOnRequestCloseDel onRequestCloseDel;
    
    EventOnRendableDel onVisibleDel, onInvisibleDel;
    
    this(bool processOwns) {
        this.ownedByProcess = processOwns;
        
        if (processOwns)
            windowToIdMapper[__handle] = cast(shared)this;
    }
    
    ~this() {
        if (ownedByProcess)
            windowToIdMapper.remove(__handle);
    }
    
    @property {
        bool visible() { return renderable; }
        IRenderEvents events() { return this; }
        IWindowEvents windowEvents() { return this; }
        IAllocator allocator() { return alloc; }
        IContext context() { return context_; }
        
        void onForcedDraw(EventOnForcedDrawDel del) { onDrawDel = del; }
        void onCursorMove(EventOnCursorMoveDel del) { onCursorMoveDel = del; }
        void onCursorAction(EventOnCursorActionDel del) { onCursorActionDel = del; }
        void onCursorActionEnd(EventOnCursorActionDel del) { onCursorActionEndDel = del; }
        void onScroll(EventOnScrollDel del) { onScrollDel = del; }
        void onClose(EventOnCloseDel del) { onCloseDel = del; }
        void onKeyEntry(EventOnKeyDel del) { onKeyEntryDel = del; }
        void onSizeChange(EventOnSizeChangeDel del) { onSizeChangeDel = del; }
        
        void onFileDragStart(EvenOnFileDragDel del) { onFileDragStartDel = del; }
        void onFileDragStopped(EvenOnFileDragDel del) { onFileDragStopDel = del; }
        void onFileDrop(EventOnFileDropDel del) { onFileDropDel = del; }
        void onFileDragging(EventOnFileDraggingDel del) { onFileDraggingDel = del; }
        
        void onMove(EventOnMoveDel del) { onMoveDel = del; }
        void onRequestClose(EventOnRequestCloseDel del) { onRequestCloseDel = del; }
        void onKeyPress(EventOnKeyDel del) { onKeyPressDel = del; }
        void onKeyRelease(EventOnKeyDel del) { onKeyReleaseDel = del; }
        
        void onVisible(EventOnRendableDel del) { onVisibleDel = del; }
        void onInvisible(EventOnRendableDel del) { onInvisibleDel = del; }
    }
}
