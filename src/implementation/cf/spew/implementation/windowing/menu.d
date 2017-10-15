module cf.spew.implementation.windowing.menu;
import cf.spew.implementation.windowing.misc;
import cf.spew.implementation.instance;
import cf.spew.ui.window.features.menu;
import cf.spew.ui.rendering : vec2;
import devisualization.util.core.memory.managed;
import std.experimental.allocator : IAllocator, make, makeArray, expandArray, dispose;
import devisualization.image : ImageStorage;
import std.experimental.color : RGB8, RGBA8;

class MenuItemImpl : Window_MenuItem {
	import std.experimental.containers.list;
	
	private {
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

version(Windows) {
	final class MenuItemImpl_WinAPI : MenuItemImpl {
		import cf.spew.implementation.windowing.window : WindowImpl_WinAPI;
		import std.traits : isSomeString;
		import core.sys.windows.windows : HMENU, HBITMAP, AppendMenuA, CreateMenu,
			ModifyMenuA, RemoveMenu, DeleteMenu, DeleteObject, MENUITEMINFOA, GetMenuItemInfoA,
			HDC, GetDC, CreateCompatibleDC, DeleteDC, ReleaseDC, BITMAP, GetObjectA, ModifyMenuW,
			MF_BYCOMMAND, MF_POPUP, UINT_PTR, GetMenuStringW, MF_STRING, GetMenuState, MF_BITMAP,
			MF_SEPARATOR, MF_DISABLED, MF_ENABLED, DrawMenuBar;
		
		package(cf.spew) {
			WindowImpl_WinAPI window;
			
			HMENU parent;
			HMENU myChildren;
			HBITMAP lastBitmap;
			wchar[] textBuffer;
		}
		
		this(WindowImpl_WinAPI window, HMENU parent, MenuItemImpl_WinAPI parentMenuItem=null) {
			import std.experimental.containers.list;
			this.window = window;
			this.parent = parent;
			this.parentMenuItem = parentMenuItem;
			
			menuItems = List!Window_MenuItem(window.alloc);
			
			menuItemId = window.menuItemsCount;
			window.menuItemsCount++;

			window.menuItemsIds[menuItemId] = this;
			AppendMenuA(parent, 0, menuItemId, null);
			DrawMenuBar(window.hwnd);
		}

		override {
			Window_MenuItem addItem() {
				if (myChildren is null) {
					myChildren = CreateMenu();
				}

				ModifyMenuW(parent, menuItemId, MF_BYCOMMAND | MF_POPUP, cast(UINT_PTR) myChildren, textBuffer.ptr);
				return cast(Window_MenuItem)window.alloc.make!MenuItemImpl_WinAPI(window, myChildren, this);
			}
			
			void remove() {
				foreach(sub; menuItems) {
					sub.remove();
				}
				
				menuItems.length = 0;
				
				RemoveMenu(parent, menuItemId, MF_BYCOMMAND);
				DeleteMenu(parent, menuItemId, MF_BYCOMMAND);
				
				if (parentMenuItem is null)
					window.menuItems.remove(cast(Window_MenuItem)this);
				else
					parentMenuItem.menuItems.remove(this);
				
				window.menuItemsIds.remove(menuItemId);
				window.menuCallbacks.remove(menuItemId);

				if (lastBitmap !is null)
					DeleteObject(lastBitmap);
				if (textBuffer !is null)
					window.alloc.dispose(textBuffer);
				
				window.alloc.dispose(this);
				DrawMenuBar(window.hwnd);
			}
			
			@property {
				managed!(Window_MenuItem[]) childItems() {
					return cast(managed!(Window_MenuItem[]))menuItems[];
				}
				
				managed!(ImageStorage!RGB8) image() {
					MENUITEMINFOA mmi;
					mmi.cbSize = MENUITEMINFOA.sizeof;
					GetMenuItemInfoA(parent, menuItemId, false, &mmi);
					
					HDC hFrom = GetDC(null);
					HDC hMemoryDC = CreateCompatibleDC(hFrom);
					
					scope(exit) {
						DeleteDC(hMemoryDC);
						ReleaseDC(window.hwnd, hFrom);
					}
					
					BITMAP bm;
					GetObjectA(mmi.hbmpItem, BITMAP.sizeof, &bm);
					
					return managed!(ImageStorage!RGB8)(bitmapToImage_WinAPI(mmi.hbmpItem, hMemoryDC, vec2!size_t(bm.bmWidth, bm.bmHeight), window.alloc), managers(), window.alloc);
				}
				
				void image(scope ImageStorage!RGB8 input) {
					HDC hFrom = GetDC(null);
					HDC hMemoryDC = CreateCompatibleDC(hFrom);
					
					scope(exit) {
						DeleteDC(hMemoryDC);
						ReleaseDC(window.hwnd, hFrom);
					}
					
					HBITMAP bitmap = imageToBitmap_WinAPI(input, hMemoryDC, window.alloc);
					ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_BITMAP, 0, cast(const(char)*)bitmap);

					if (lastBitmap !is null)
						DeleteObject(lastBitmap);
					lastBitmap = bitmap;

					DrawMenuBar(window.hwnd);
				}
				
				managed!dstring text() {
					import std.utf : count, byDchar;
					wchar[32] buffer;
					int length = GetMenuStringW(parent, menuItemId, buffer.ptr, buffer.length, MF_BYCOMMAND);
					assert(length >= 0);

					auto realLength = count(buffer[0 .. length]);

					dchar[] buffer2 = window.alloc.makeArray!dchar(realLength);
					size_t i;
					foreach(c; buffer[0 .. length].byDchar) {
						buffer2[i] = c;
						i++;
					}
					
					return managed!dstring(cast(dstring)buffer2, managers(), window.alloc);
				}
				
				void text(dstring input) { setText(input); }
				void text(wstring input) { setText(input); }
				void text(string input) { setText(input); }
				
				bool divider() {
					return (GetMenuState(parent, menuItemId, MF_BYCOMMAND) & MF_SEPARATOR) == MF_SEPARATOR;
				}
				
				void divider(bool v) {
					if (v)
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_SEPARATOR, 0, null);
					else
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND & ~MF_SEPARATOR, 0, null);
					
					DrawMenuBar(window.hwnd);
				}
				
				bool disabled() {
					return (GetMenuState(parent, menuItemId, MF_BYCOMMAND) & MF_DISABLED) == MF_DISABLED;
				}
				
				void disabled(bool v) {
					if (v)
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_DISABLED, 0, null);
					else
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_ENABLED, 0, null);
					
					DrawMenuBar(window.hwnd);
				}
				
				void callback(Window_MenuCallback callback) {
					window.menuCallbacks[menuItemId] = callback;
				}
			}
		}

		void setText(T)(T input) if (isSomeString!T) {
			import std.utf : byWchar;

			if (textBuffer !is null)
				window.alloc.dispose(textBuffer);
			wchar[] buffer = window.alloc.makeArray!wchar(input.length);
			
			size_t i;
			foreach(c; input.byWchar) {
				if (i > buffer.length)
					window.alloc.expandArray(buffer, 1);
				
				buffer[i] = c;
				i++;
			}
			
			window.alloc.expandArray(buffer, 1); // \0 last byte
			buffer[$-1] = '\0';
			
			ModifyMenuW(parent, menuItemId, MF_BYCOMMAND | MF_STRING, menuItemId, cast(const(wchar)*)buffer.ptr);
			this.textBuffer = buffer;
			DrawMenuBar(window.hwnd);
		}
	}
}