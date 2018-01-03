/**
 * Management_UserInterface clipboard support.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.features.clipboard;
import cf.spew.instance;
import devisualization.util.core.memory.managed;
import std.experimental.allocator : IAllocator, theAllocator;

interface Have_Management_Clipboard {
	shared(Feature_Management_Clipboard) __getFeatureClipboard() shared;
}

///
interface Feature_Management_Clipboard {
	@property {
		///
		void maxClipboardDataSize(size_t amount) shared;
		///
		size_t maxClipboardDataSize() shared;
		///
		managed!string clipboardText(IAllocator alloc=theAllocator()) shared;
		///
		void clipboardText(scope string text) shared;
	}
}

@property {
	/// Gets the maximum size of data to store from/on the clipboard
	size_t maxClipboardDataSize(scope shared(Management_UserInterface) self) {
		if (!self.capableOfClipboard)
			return 0;
		else {
			return (cast(shared(Have_Management_Clipboard))self).__getFeatureClipboard().maxClipboardDataSize();
		}
	}

	/// Sets the maximum size for data on the clipboard to store
	void maxClipboardDataSize(scope shared(Management_UserInterface) self, size_t amount) {
		if (!self.capableOfClipboard)
			return;
		else {
			(cast(shared(Have_Management_Clipboard))self).__getFeatureClipboard().maxClipboardDataSize(amount);
		}
	}

	/// Copies a UTF8 string from the clipboard
	managed!string clipboardText(scope shared(Management_UserInterface) self, IAllocator alloc=theAllocator()) {
		if (!self.capableOfClipboard)
			return managed!string.init;
		else {
			return (cast(shared(Have_Management_Clipboard))self).__getFeatureClipboard().clipboardText(alloc);
		}
	}

	/// Copies the given UTF8 string into the clipboard
	void clipboardText(scope shared(Management_UserInterface) self, scope string content) {
		if (!self.capableOfClipboard)
			return;
		else {
			(cast(shared(Have_Management_Clipboard))self).__getFeatureClipboard().clipboardText(content);
		}
	}

	/**
	 * Does the given user interface manager have a clipboard?
	 * 
	 * Params:
	 * 		self	=	The user interface manager instance
	 * 
	 * Returns:
	 * 		If the platform supports having a clipboard
	 */
	bool capableOfClipboard(scope shared(Management_UserInterface) self) {
		if (self is null)
			return false;
		else if (auto ss = cast(shared(Have_Management_Clipboard))self)
			return ss.__getFeatureClipboard() !is null;
		else
			return false;
	}
}