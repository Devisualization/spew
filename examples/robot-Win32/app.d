import devisualization.util.core.memory.managed;
import cf.spew.instance;
import cf.spew.ui;
import cf.spew.events.windowing : CursorEventAction, SpecialKey;
import std.stdio;

void main() {
	managed!IWindow window = Instance.current.robot.findWindow("Untitled - Notepad");
	
	if (window.isNull) {
		writeln("There is no window with a title of \"Untitled - Notepad\".");
		return;
	} else {
		writeln("Found a window with the title of \"Untitled - Notepad\".");
		
		auto prevFocussed = Instance.current.robot.focusWindow;
		Instance.current.robot.focusWindow = window;
		foreach(c; "Say hello!") {
			Instance.current.robot.sendKey(c, 0, window);
		}
		Instance.current.robot.sendKey(SpecialKey.Enter, window);
		Instance.current.robot.focusWindow = prevFocussed;
	}
}