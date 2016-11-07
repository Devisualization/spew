﻿module cf.spew.implementation.windowing.menu;
import cf.spew.implementation.windowing.misc;
import cf.spew.implementation.instance;
import cf.spew.ui.window.features.menu;
import cf.spew.ui.rendering : vec2;
import std.experimental.memory.managed;
import std.experimental.allocator : IAllocator, make, makeArray, expandArray, dispose;
import std.experimental.graphic.image : ImageStorage;
import std.experimental.graphic.color : RGB8, RGBA8;

class MenuItemImpl : MenuItem {
	import std.experimental.containers.list;
	
	private {
		List!MenuItem menuItems = void;
		
		uint menuItemId;
		MenuItemImpl parentMenuItem;
	}
	
	abstract {
		MenuItem addChildItem();
		void remove();
		
		@property {
			managed!(MenuItem[]) childItems();
			managed!(ImageStorage!RGB8) image();
			void image(ImageStorage!RGB8 input);
			
			managed!dstring text();
			void text(string text);
			void text(wstring text);
			void text(dstring text);
			
			bool divider();
			void divider(bool v);
			bool disabled();
			void disabled(bool v);
			void callback(MenuCallback callback);
		}
	}
}

version(Windows) {
	final class MenuItemImpl_WinAPI : MenuItemImpl {
		import cf.spew.implementation.windowing.window : WindowImpl_WinAPI;
		import std.traits : isSomeString;
		import core.sys.windows.windows : HMENU, HBITMAP, AppendMenuA, CreatePopupMenu,
			ModifyMenuA, RemoveMenu, DeleteMenu, DeleteObject, MENUITEMINFOA, GetMenuItemInfoA,
			HDC, GetDC, CreateCompatibleDC, DeleteDC, ReleaseDC, BITMAP, GetObjectA, ModifyMenuW,
			MF_BYCOMMAND, MF_POPUP, UINT_PTR, GetMenuStringW, MF_STRING, GetMenuState, MF_BITMAP,
			MF_SEPARATOR, MF_DISABLED, MF_ENABLED;
		
		package(cf.spew) {
			WindowImpl_WinAPI window;
			
			HMENU parent;
			HMENU myChildren;
			HBITMAP lastBitmap;
		}
		
		this(WindowImpl_WinAPI window, HMENU parent, MenuItemImpl_WinAPI parentMenuItem=null) {
			import std.experimental.containers.list;
			this.window = window;
			this.parent = parent;
			this.parentMenuItem = parentMenuItem;
			
			menuItems = List!MenuItem(window.alloc);
			
			menuItemId = window.menuItemsCount;
			window.menuItemsCount++;
			
			AppendMenuA(parent, 0, menuItemId, null);
			window.redrawMenu = true;
		}
		
		override {
			MenuItem addChildItem() {
				if (myChildren is null) {
					myChildren = CreatePopupMenu();
				}
				
				ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_POPUP, cast(UINT_PTR) myChildren, null);
				return cast(MenuItem)window.alloc.make!MenuItemImpl_WinAPI(window, myChildren, this);
			}
			
			void remove() {
				foreach(sub; menuItems) {
					sub.remove();
				}
				
				menuItems.length = 0;
				
				RemoveMenu(parent, menuItemId, MF_BYCOMMAND);
				DeleteMenu(parent, menuItemId, MF_BYCOMMAND);
				
				if (parentMenuItem is null)
					window.menuItems.remove(cast(MenuItem)this);
				else
					parentMenuItem.menuItems.remove(this);
				
				window.menuCallbacks.remove(menuItemId);
				if (lastBitmap !is null)
					DeleteObject(lastBitmap);
				
				window.redrawMenu = true;
				window.alloc.dispose(this);
			}
			
			@property {
				managed!(MenuItem[]) childItems() {
					return cast(managed!(MenuItem[]))menuItems[];
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
					
					return managed!(ImageStorage!RGB8)(bitmapToImage_WinAPI(mmi.hbmpItem, hMemoryDC, vec2!size_t(bm.bmWidth, bm.bmHeight), window.alloc), managers(), Ownership.Secondary, window.alloc);
				}
				
				void image(ImageStorage!RGB8 input) {
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
					
					window.redrawMenu = true;
				}
				
				managed!dstring text() {
					wchar[32] buffer;
					int length = GetMenuStringW(parent, menuItemId, buffer.ptr, buffer.length, MF_BYCOMMAND);
					assert(length >= 0);
					
					dchar[] buffer2 = window.alloc.makeArray!dchar(length);
					buffer2[0 .. length] = cast(dchar[])buffer[0 .. length];
					
					return managed!dstring(cast(dstring)buffer2, managers(), Ownership.Secondary, window.alloc);
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
					
					window.redrawMenu = true;
				}
				
				bool disabled() {
					return (GetMenuState(parent, menuItemId, MF_BYCOMMAND) & MF_DISABLED) == MF_DISABLED;
				}
				
				void disabled(bool v) {
					if (v)
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_DISABLED, 0, null);
					else
						ModifyMenuA(parent, menuItemId, MF_BYCOMMAND | MF_ENABLED, 0, null);
					
					window.redrawMenu = true;
				}
				
				void callback(MenuCallback callback) {
					window.menuCallbacks[menuItemId] = callback;
				}
			}
		}

		void setText(T)(T input) if (isSomeString!T) {
			import std.utf : byWchar;
			
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
			
			ModifyMenuW(parent, menuItemId, MF_BYCOMMAND | MF_STRING, 0, cast(const(wchar)*)buffer.ptr);
			window.alloc.dispose(buffer);
			
			window.redrawMenu = true;
		}
	}
}