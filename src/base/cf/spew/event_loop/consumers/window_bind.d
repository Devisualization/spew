/// Binds a window location + size to anothers
module cf.spew.event_loop.consumers.window_bind;
import cf.spew.event_loop.defs;
import cf.spew.events.defs;

/// Does not handle closing, just location + size from external sources
class WindowBind : EventLoopConsumer {
	protected {
		import cf.spew.events.windowing : Windowing_Events_Types;
		import cf.spew.ui.window.defs : IWindow;
		import cf.spew.ui.rendering : vec2;
		import std.typecons : Nullable;

		IWindow owner_, child_;
	}

	this(IWindow owner, IWindow child, ushort offsetX=0, ushort offsetY=0, bool bindSize=true) {
		owner_ = owner;
		child_ = child;
		offsetX = offsetX;
		offsetY = offsetY;
		bindSize = bindSize;
	}

	///
	ushort offsetX, offsetY;
	///
	bool bindSize;
	///
	bool enabled = true;

	@property {
		///
		IWindow owner() { return owner_; }
		///
		IWindow child() { return child_; }

		bool onMainThread() { return true; }
		bool onAdditionalThreads() { return true; }
		string description() { return "Binds two windows location + size together with an offset."; }

		Nullable!EventSource pairOnlyWithSource() { return Nullable!EventSource.init; }
		EventType pairOnlyWithEvents() { return Windowing_Events_Types.Prefix; }
		byte priority() { return 0; }
	}

	bool processEvent(ref Event event) {
		if (enabled && event.wellData1Ptr is owner.__handle) {
			// ok so it is the owner, yay!

			switch(event.type) {
				case Windowing_Events_Types.Window_Moved:
					child.location = vec2!int(cast(int)(event.windowing.windowMoved.newX + offsetX),
						cast(int)(event.windowing.windowMoved.newY + offsetY));
					break;

				case Windowing_Events_Types.Window_Resized:
					if (bindSize) {
						// if new size <= 0 then hide child, not our problem!
						// otherwise set size
						if (event.windowing.windowResized.newWidth <= 0 || event.windowing.windowResized.newHeight <= 0) {
							child.hide();
							// yuckies
						} else {
							vec2!uint s = child.size;
							if (s.x + event.windowing.windowResized.newWidth <= offsetX ||
								s.y + event.windowing.windowResized.newHeight <= offsetY) {

								child.hide();
								// gah
							} else {
								// ok we can resize, yay!
								// but that resized value better be the client area!
								child.size = vec2!uint(cast(uint)(event.windowing.windowResized.newWidth-offsetX),
									cast(uint)(event.windowing.windowResized.newHeight-offsetY));
							}
						}
					}
					break;

				default:
					break;
			}
		}

		return false;
	}
}