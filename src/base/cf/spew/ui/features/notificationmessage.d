/**
 * Notification message support for an application.
 *
 * Depends upon notification tray support.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.features.notificationmessage;
import cf.spew.ui.window.defs;
import cf.spew.instance;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import devisualization.util.core.memory.managed;
import stdx.allocator : ISharedAllocator, processAllocator;
import std.traits : isSomeString;

interface Have_NotificationMessage {
	shared(Feature_NotificationMessage) __getFeatureNotificationMessage() shared;
}

interface Feature_NotificationMessage {
	void notify(shared(ImageStorage!RGBA8), dstring, dstring, shared(ISharedAllocator) alloc) shared;
	void clearNotifications() shared;
}

/**
 *  Sends a notification message to the user for the current application, optionally setting an image and title
 * 
 * If the title and text is not a dstring it will automatically convert it to dstring and deallocate after usage.
 * If the implementation needs to keep the value it around it will copy it.
 * 
 * Params:
 * 		self	=	The platform instance
 * 		image	=	An image to display along with the message
 * 		title	=	A title to give the user
 * 		text	=	The message text to tell the user
 * 		alloc	=	Allocator to allocate and copy resources for while notification is active
 */
void notify(S1, S2)(shared(Management_UserInterface) self, shared(ImageStorage!RGBA8) image=null, S1 title=null, S2 text=null, shared(ISharedAllocator) alloc=processAllocator) if (isSomeString!S1 && isSomeString!S2) {
	if (self is null)
		return;
    if (shared(Have_NotificationMessage) ss = cast(shared(Have_NotificationMessage))self) {
		import std.utf : byDchar, codeLength;
		import stdx.allocator : makeArray, dispose;

        auto fss = ss.__getFeatureNotificationMessage();

		dchar[] titleUse, textUse;
        size_t offset;

		static if (is(S1 == dstring)) {
			titleUse = cast(dchar[])title;
		} else {
			titleUse = alloc.makeArray!dchar(codeLength!dchar(title));

            offset = 0;
			foreach(c; title.byDchar) {
				titleUse[offset++] = c;
			}
		}

		static if (is(S2 == dstring)) {
			textUse = cast(dchar[])text;
		} else {
            textUse = alloc.makeArray!dchar(codeLength!dchar(text));
			
            offset = 0;
            foreach(c; text.byDchar) {
                textUse[offset++] = c;
			}
		}

		if (fss !is null) {
			fss.notify(image, cast(dstring)titleUse, cast(dstring)textUse, alloc);
		}

		static if (!is(S1 == dstring))
			alloc.dispose(titleUse);
		static if (!is(S2 == dstring))
			alloc.dispose(textUse);
	}
}

/**
 * Forces deallocation and removal of all current and past (still stored) notifications
 *
 * Params:
 * 		self	=	The platform instance
 */
void clearNotifications(shared(Management_UserInterface) self) {
	if (self is null)
		return;
    if (shared(Have_NotificationMessage) ss = cast(shared(Have_NotificationMessage))self) {
        auto fss = ss.__getFeatureNotificationMessage();
		if (fss !is null) {
			fss.clearNotifications();
		}
	}
}

/**
 * Does the given platform support notification messages for the user?
 * 
 * Params:
 * 		self	=	The platform instance
 * 
 * Returns:
 * 		If the platform supports notification messages
 */
@property bool capableOfNotificationMessage(shared(Management_UserInterface) self) {
	if (self is null)
		return false;
    else if (shared(Have_NotificationMessage) ss = cast(shared(Have_NotificationMessage))self)
		return ss.__getFeatureNotificationMessage() !is null;
	else
		return false;
}