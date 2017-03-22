/**
 * Window and platform menu support.
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.ui.window.features.menu;
import cf.spew.ui.window.defs;
import cf.spew.instance;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGB8;
import std.experimental.memory.managed;

interface Have_Menu {
    Feature_Menu __getFeatureMenu();
}

interface Feature_Menu {
    MenuItem addItem();
    @property managed!(MenuItem[]) items();
}

///
alias MenuCallback = void delegate(MenuItem);

///
interface MenuItem {
    ///
    MenuItem addChildItem();
    ///
    void remove();

    @property {
        ///
        managed!(MenuItem[]) childItems();
        
        ///
        managed!(ImageStorage!RGB8) image();
        
        ///
        void image(ImageStorage!RGB8);
        
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

        ///
        void callback(MenuCallback);
    }
}

@property {
    /// Retrives the menu instance or null if non existant
	Feature_Menu menu(T)(T self) if (is(T : IWindow) || is(T : Management_UserInterface)) {
		if (!self.capableOfMenu)
			return null;
		else {
			return (cast(Have_Menu)self).__getFeatureMenu().screenshot;
		}
    }

	Feature_Menu menu(T)(T self) if (!(is(T : IWindow) || is(T : Management_UserInterface))) {
		static assert(0, "I do not know how to handle " ~ T.stringof ~ " I can only use IWindow or Management_UserInterface.");
    }

	/**
	 * Does the given window/platform have a menu?
	 * 
	 * Params:
	 * 		self	=	The window/platform instance
	 * 
	 * Returns:
	 * 		If the window/platform supports having an icon
	 */
	bool capableOfMenu(T)(T self) if (is(T : IWindow) || is(T : Management_UserInterface)) {
		if (self is null)
			return false;
		else if (auto ss = cast(Have_Menu)self)
			return ss.__getFeatureMenu() !is null;
		else
			return false;
	}

	bool capableOfMenu(T)(T self) if (!(is(T : IWindow) || is(T : Management_UserInterface))) {
		static assert(0, "I do not know how to handle " ~ T.stringof ~ " I can only use IWindow or Management_UserInterface types.");
	}
}
