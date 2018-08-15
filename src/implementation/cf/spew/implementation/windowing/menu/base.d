module cf.spew.implementation.windowing.menu.base;
import cf.spew.ui.window.features.menu;
import devisualization.util.core.memory.managed;
import std.experimental.containers.list;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8, RGBA8;

abstract class MenuItemImpl : Window_MenuItem {
    package(cf.spew.implementation) {
        List!Window_MenuItem menuItems = void;

        uint menuItemId;
        MenuItemImpl parentMenuItem;
    }

    abstract {
        Window_MenuItem addItem();
        void remove();

        @property {
            managed!(Window_MenuItem[]) childItems();
            managed!(ImageStorage!RGB8) image();
            void image(scope ImageStorage!RGB8 input);

            managed!dstring text();
            void text(string text);
            void text(wstring text);
            void text(dstring text);

            bool divider();
            void divider(bool v);
            bool disabled();
            void disabled(bool v);
            void callback(Window_MenuCallback callback);
        }
    }
}
