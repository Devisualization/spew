module cf.spew.miscellaneous.filewatcher;
import std.functional : toDelegate;

alias FileSystemWatcherEventDel = void delegate(scope IFileSystemWatcher timer, scope string name);
alias FileSystemWatcherEventFunc = void function(scope IFileSystemWatcher timer, scope string name);

interface IFileSystemWatcher {
    @property {
        scope string path();
    }

    void stop();

    void onChange(FileSystemWatcherEventDel del);
    final void onChange(FileSystemWatcherEventFunc func) {
        onChange = func.toDelegate;
    }

    void onCreate(FileSystemWatcherEventDel del);
    final void onCreate(FileSystemWatcherEventFunc func) {
        onCreate = func.toDelegate;
    }

    void onDelete(FileSystemWatcherEventDel del);
    final void onDelete(FileSystemWatcherEventFunc func) {
        onDelete = func.toDelegate;
    }
}
