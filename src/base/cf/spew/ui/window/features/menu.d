/**
 * Window menu support.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.features.menu;
import cf.spew.ui.window.defs;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGB8;
import std.experimental.memory.managed;

interface Have_Window_MenuCreator {
	void assignMenu();
}

interface Have_Window_Menu {
	Feature_Window_Menu __getFeatureMenu();
}

interface Feature_Window_Menu {
	Window_MenuItem addItem();
	@property managed!(Window_MenuItem[]) items();
}

///
alias MenuCallback = void delegate(Window_MenuItem);

///
interface Window_MenuItem {
    ///
	Window_MenuItem addItem();
    ///
    void remove();

    @property {
        ///
		managed!(Window_MenuItem[]) childItems();
        
        ///
        managed!(ImageStorage!RGB8) image();
        
        ///
        void image(scope ImageStorage!RGB8);
        
        ///
        managed!dstring text();
        
        ///
        void text(dstring);
        
        ///
        void text(wstring);
        
        ///
        void text(string);

        ///
        bool divider();
        
        ///
        void divider(bool);

        ///
        bool disabled();

        ///
        void disabled(bool);

        /// Not valid if there are children
        void callback(MenuCallback);
    }
}

///
void assignMenu(scope IWindowCreator self) {
	if (Have_Window_MenuCreator ss = cast(Have_Window_MenuCreator)self) {
		ss.assignMenu();
	}
}

@property {
    /// Retrives the menu instance or null if non existant
	Feature_Window_Menu menu(scope IWindow self) {
		if (!self.capableOfMenu)
			return null;
		else {
			return (cast(Have_Window_Menu)self).__getFeatureMenu();
		}
    }

	/**
	 * Does the given window have a menu?
	 * 
	 * Params:
	 * 		self	=	The window instance
	 * 
	 * Returns:
	 * 		If the window/platform supports having an icon
	 */
	bool capableOfMenu(scope IWindow self) {
		if (self is null)
			return false;
		else if (auto ss = cast(Have_Window_Menu)self)
			return ss.__getFeatureMenu() !is null;
		else
			return false;
	}
}
