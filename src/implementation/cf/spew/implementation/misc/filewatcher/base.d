module cf.spew.implementation.misc.filewatcher.base;
import cf.spew.miscellaneous.filewatcher;
import stdx.allocator : IAllocator, dispose;

abstract class FileSystemWatcherImpl : IFileSystemWatcher {
    package(cf.spew.implementation) {
        IAllocator alloc;

        // some weirdo bug for dmd.
        version (DigitalMars) {
            ubyte[4] padding1;
        }
        char[] thePath;

        FileSystemWatcherEventDel onChangeDel, onCreateDel, onDeleteDel;
    }

    ~this() {
        alloc.dispose(thePath);
    }

    this(char[] path, IAllocator alloc) {
        this.thePath = path;
        this.alloc = alloc;
    }

    @property {
        scope string path() {
            return cast(string)thePath;
        }
    }

    void onChange(FileSystemWatcherEventDel del) {
        onChangeDel = del;
    }

    void onCreate(FileSystemWatcherEventDel del) {
        onCreateDel = del;
    }

    void onDelete(FileSystemWatcherEventDel del) {
        onDeleteDel = del;
    }
}
