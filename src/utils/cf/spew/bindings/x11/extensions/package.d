module cf.spew.bindings.x11.extensions;
public import cf.spew.bindings.x11.extensions.randr;
public import cf.spew.bindings.x11.extensions.render;
public import cf.spew.bindings.x11.extensions.Xrandr;
public import cf.spew.bindings.x11.extensions.Xrender;
import cf.spew.bindings.autoloader;
import cf.spew.bindings.symbolloader : SELF_SYMBOL_LOOKUP;

///
__gshared static XrandrLoader = new SharedLibAutoLoader!([`cf.spew.bindings.x11.extensions.Xrandr`,])("Xrandr", SELF_SYMBOL_LOOKUP);
///
__gshared static XrenderLoader = new SharedLibAutoLoader!([`cf.spew.bindings.x11.extensions.Xrender`])("Xrender", SELF_SYMBOL_LOOKUP);
