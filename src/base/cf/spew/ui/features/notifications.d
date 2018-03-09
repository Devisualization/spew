/**
 * Notification support for an application.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.features.notifications;
import cf.spew.ui.window.defs;
import cf.spew.instance;
import devisualization.image : ImageStorage;
import std.experimental.color : RGBA8;
import devisualization.util.core.memory.managed;
import stdx.allocator : ISharedAllocator, processAllocator;
import std.traits : isSomeString;

interface Have_Notification {
	shared(Feature_Notification) __getFeatureNotification() shared;
}

interface Feature_Notification {
	@property {
		shared(ImageStorage!RGBA8) getNotificationIcon(shared(ISharedAllocator) alloc) shared;
		void setNotificationIcon(shared(ImageStorage!RGBA8), shared(ISharedAllocator) alloc) shared;
	}

	void notify(shared(ImageStorage!RGBA8), shared(dstring), shared(dstring), shared(ISharedAllocator) alloc) shared;
	void clearNotifications() shared;
}

/**
 * Assigns a notification icon to the given application
 * 
 * Params:
 * 		self	=	The platform instance
 * 		to		=	The image to assign as
 * 		alloc	=	The allocator to use during assignment
 */
void notificationIcon(shared(Management_UserInterface) self, shared(ImageStorage!RGBA8) to, shared(ISharedAllocator) alloc=processAllocator) {
	if (self is null)
		return;
	if (shared(Have_Notification) ss = cast(shared(Have_Notification))self) {
		auto fss = ss.__getFeatureNotification();
		if (fss !is null) {
			fss.setNotificationIcon(to, alloc);
		}
	}
}

/**
 * Retrieve the applications notification icon
 * 
 * Params:
 * 		self	=	The platform instance
 * 		alloc	=	The allocator to allocate/deallocate during creation
 * 
 * Returns:
 * 		The notification icon for the current process (will auto deallocate)
 */
managed!(shared(ImageStorage!RGBA8)) notificationIcon(shared(Management_UserInterface) self, shared(ISharedAllocator) alloc=processAllocator) {
	if (self is null)
		return (managed!(shared(ImageStorage!RGBA8))).init;
	if (shared(Have_Notification) ss = cast(shared(Have_Notification))self) {
		auto fss = ss.__getFeatureNotification();
		if (fss !is null) {
			return managed!(shared(ImageStorage!RGBA8))(fss.getNotificationIcon(alloc), managers(ReferenceCountedManager()), alloc);
		}
	}
	return (managed!(shared(ImageStorage!RGBA8))).init;
}

/**
 *  Sends a notification to the user for the current application, optionally setting an image and title
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
void notify(S1, S2)(shared(Management_UserInterface) self, shared(ImageStorage!RGBA8) image=null, shared(S1) title=null, shared(S2) text=null, shared(ISharedAllocator) alloc=processAllocator) if (isSomeString!S1 && isSomeString!S2) {
	if (self is null)
		return;
	if (shared(Have_Notification) ss = cast(shared(Have_Notification))self) {
		import std.utf : byDchar, codeLength;
		import stdx.allocator : makeArray, dispose;

		auto fss = ss.__getFeatureNotification();

		dchar[] titleUse, textUse;

		static if (is(S1 == dstring)) {
			titleUse = cast(dchar[])title;
		} else {
			titleUse = alloc.makeArray!dchar(codeLength!dstring(title));

			foreach(i, c; title.byDchar) {
				titleUse[i] = c;
			}
		}

		static if (is(S2 == dstring)) {
			textUse = cast(dchar[])text;
		} else {
			textUse = alloc.makeArray!dchar(codeLength!dstring(text));
			
			foreach(i, c; text.byDchar) {
				textUse[i] = c;
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
	if (shared(Have_Notification) ss = cast(shared(Have_Notification))self) {
		auto fss = ss.__getFeatureNotification();
		if (fss !is null) {
			fss.clearNotifications();
		}
	}
}

/**
 * Does the given platform support notifications for the user?
 * 
 * Params:
 * 		self	=	The platform instance
 * 
 * Returns:
 * 		If the platform supports notifications
 */
@property bool capableOfNotifications(shared(Management_UserInterface) self) {
	if (self is null)
		return false;
	else if (shared(Have_Notification) ss = cast(shared(Have_Notification))self)
		return ss.__getFeatureNotification() !is null;
	else
		return false;
}