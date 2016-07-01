module cf.spew.bindings.x11;
public import cf.spew.bindings.x11.keysym;
public import cf.spew.bindings.x11.keysymdef;
public import cf.spew.bindings.x11.X;
// most likely not needed and does redefine things == error
//public import cf.spew.bindings.x11.Xdefs;
public import cf.spew.bindings.x11.Xlib;
public import cf.spew.bindings.x11.Xmd;
public import cf.spew.bindings.x11.Xproto;
public import cf.spew.bindings.x11.Xprotostr;
public import cf.spew.bindings.x11.Xresource;
public import cf.spew.bindings.x11.Xutil;

public import cf.spew.bindings.x11.extensions;

import cf.spew.bindings.autoloader;
import cf.spew.bindings.symbolloader : SELF_SYMBOL_LOOKUP;

///
__gshared static X11Loader = new SharedLibAutoLoader!([
	`cf.spew.bindings.x11.Xlib`,
	`cf.spew.bindings.x11.Xresource`,
	`cf.spew.bindings.x11.Xutil`
])("X11", SELF_SYMBOL_LOOKUP);
