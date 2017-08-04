/**
 * OpenGL loader
 *
 * Copyright: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors: $(LINK2 http://cattermole.co.nz, Richard Andrew Cattermole)
 */
module cf.spew.bindings.opengl.loader;

version(Windows) {
	static string[] Default_OpenGL_FileNames = ["opengl32.dll"];
	static import defaultgl = cf.spew.bindings.opengl.gl;
} else version(OSX) {
	static string[] Default_OpenGL_FileNames = ["../Frameworks/OpenGL.framework/OpenGL", "/Library/Frameworks/OpenGL.framework/OpenGL", "/System/Library/Frameworks/OpenGL.framework/OpenGL"];
	static import defaultgl = cf.spew.bindings.opengl.gl;
} else version(Posix) {
	static string[] Default_OpenGL_FileNames = ["libGL.so.1", "libGL.so"];
	static import defaultgl = cf.spew.bindings.opengl.gl;
} else {
	pragma(msg, "Warning: OpenGL may not supported on this platform. ", __MODULE__, " bindings are not implemented");
}

struct OpenGL_Loader(T_Callbacks, T_Bindings=defaultgl.GL, T_Bindings_ExtensionUDA=defaultgl.OpenGL_Extension, T_Bindings_VersionUDA=defaultgl.OpenGL_Version) {
	import cf.spew.bindings.symbolloader;
	
	private{
		string[] openglFileNames;
		ushort minMajor, minMinor;
		bool loaded;
		SharedLib sharedLib;
		T_Bindings* bindings;

		alias PlatformSpecificLoaderFunc = extern(System) void* function(char*);
		PlatformSpecificLoaderFunc platformSpecificLoaderFunc;
	}

	T_Callbacks callbacks;
	
	@disable
	this(this);
	
	static if (__traits(compiles, Default_OpenGL_FileNames)) {
		this(T_Bindings* theBindings, ushort minMajor=0, ushort minMinor=0, string[] openglFileNames=Default_OpenGL_FileNames) {
			this.bindings = theBindings;
			this.minMajor = minMajor;
			this.minMinor = minMinor;
			this.openglFileNames = openglFileNames;
			init();
		}
	} else {
		this(T_Bindings* theBindings, string[] openglFileNames, ushort minMajor=0, ushort minMinor=0) {
			this.bindings = theBindings;
			this.minMajor = minMajor;
			this.minMinor = minMinor;
			this.openglFileNames = openglFileNames;
			init();
		}
	}
	
	void init() {
		static if (__traits(hasMember, T_Callbacks, "onLoad")) {
			callbacks.onLoad = &loadSymbols;
		}

		static if (__traits(hasMember, T_Callbacks, "onReload")) {
			callbacks.onReload = &reloadSymbols!true;
		}

		static if (__traits(hasMember, T_Callbacks, "loadSymbol")) {
			callbacks.loadSymbol = &getSymbol;
		}

		sharedLib.load(openglFileNames);
		assert(sharedLib.isLoaded, "OpenGL shared library failed to load.");

		loaded = true;
	}
	
	void reloadSymbols(bool LoadExtensions)() {
		import std.traits : isFunctionPointer, hasUDA;
		if (!loaded) init;

		import std.stdio;writeln("reloadSymbols!", LoadExtensions);
		foreach(m; __traits(allMembers, T_Bindings)) {
			static if (__traits(compiles, mixin("typeof(bindings." ~ m ~ ")")) && isFunctionPointer!(mixin("typeof(bindings." ~ m ~ ")"))) {

				// disable/enable extensions+versions
				static if (checkVersionExtension!(m)(LoadExtensions)) {
					void* got = getSymbol(m);
					if (got !is null)
						mixin("bindings." ~ m ~ " = cast(typeof(bindings." ~ m ~ "))got;");
				}
			}
		}
	}

	void loadSymbols(string platformSpecificFunction) {
		if (!loaded) init;
		platformSpecificLoaderFunc = null;
		if (platformSpecificFunction.length > 0)
			platformSpecificLoaderFunc = cast(PlatformSpecificLoaderFunc)getSymbol(platformSpecificFunction);
		reloadSymbols!false();
	}
	
	void* getSymbol(string name) {
		import std.string : toStringz;
		if (!loaded) init;

		void* ret;

		//import std.stdio;writeln("getSymbol: ", name);
		if (platformSpecificLoaderFunc !is null)
			ret = platformSpecificLoaderFunc(cast(char*)name.toStringz);
		if (ret is null)
			ret = sharedLib.loadSymbol(name, false);

		//import std.stdio;writeln("\t", ret);

		return ret;
	}

	private static pure {
		bool checkVersionExtension(string member)(bool enable) {
			import std.traits : hasUDA, getUDAs;

			if (is(T_Bindings_ExtensionUDA == void) || enable || 
				(!is(T_Bindings_ExtensionUDA == void) && hasUDA!(mixin("T_Bindings." ~ member), T_Bindings_ExtensionUDA) == enable)) {
				static if (!is(T_Bindings_VersionUDA == void) && hasUDA!(mixin("T_Bindings." ~ member), T_Bindings_VersionUDA)) {
					enum UDAS = getUDAs!(mixin("T_Bindings." ~ member), T_Bindings_VersionUDA);
					
					return enable || (cast(int)UDAS[0] < 30 && !enable);
				} else
					return true;
			} else
				return false;
		}
	}
}
