module diagnostic;

import core.time : Duration;
import std.experimental.allocator;
import std.experimental.memory.managed;

import cf.spew.instance;
import cf.spew.events.defs;
import cf.spew.event_loop.defs;

int main() {

	version(all) {
		import std.stdio;
		writeln("Hello there!");
		writeln("Now lets do a quick diagnostic on the platform...");
		writeln;
		writeln("It was built on ", __TIMESTAMP__, " using ", __VENDOR__, " compiler ", __VERSION__, ".");

		if (Instance.current is null) {
			writeln;
			writeln("Well that is odd, there is no implementation defined.");
			writeln("Please compile in spew:implementation or provide your own implementation.");
			writeln("Check http://code.dlang.org for more compatible implementations");
			writeln(" or have a look on the NewsGroup! http://forum.dlang.org/group/announce");

			return -1;
		}

		version(Have_spew_implementation) {
			import cf.spew.implementation.instance;

			writeln("I see you have compiled with spew:implementation enabled, good choice!");

			if (cast(DefaultImplementation)Instance.current is null) {
				writeln;
				writeln("Oh and you even have your own implementation well done!");
				writeln("But feel free to remove spew.implementation from compilation");
				writeln(" if you want smaller binaries as it is not being used");
				writeln(" ...at least in terms of cf.spew.instance abstraction.");
			}
		} else {
			writeln;
			writeln("So no idea where this implementation comes from, but that is ok.");
			writeln("That just means you've been smart and got your own one");
			writeln(" and not using the one provided with S.P.E.W. spew:implementation.");
		}

		if (Instance.current.eventLoop is null) {
			writeln;
			writeln("Andddd it appears that the event loop implementation is not all ok");
			writeln(" as it doesn't even exist.");
			return -2;
		} else if (Instance.current.eventLoop.manager is null) {
			writeln;
			writeln("Well this is strange, the event loop manager itself");
			writeln(" doesn't quite seem to exist, yet there is event loop support");
			writeln(" suposadly existing for this implementation.");
			return -3;
		}

		if (Instance.current.ui is null) {
			writeln;
			writeln("Ok well this is awkward but you haven't got a very user friendly");
			writeln(" implementation compiled in.");
			writeln("No really, it has no user interface support!");
			return -4;
		}

		writeln;
		writeln("Right so far everything looks all good and dandy.");
		writeln("But it would be nice to have more features needed to be testing!");

		writeln;
		writeln("Exporting event loop manager rules:");
		try {
			string text = Instance.current.eventLoop.manager.describeRules();
			writeln("{#####################################{");
			writeln(text);
			writeln("}#####################################}");
		} catch(Error e) {
			writeln("Failed, might not be implemented...");
			writeln("{#####################################{");
			writeln(e);
			writeln("}#####################################}");
		}

		writeln("So it looks like:");
		writeln("\t- Event loop");
		//writeln("\t- User interface");
		writeln("are all provided and functioning correctly.");
	}

	aSocketTCPClientCreate();
	aSocketTCPServerCreate();

	// normally 3s would be ok for a timeout, but ugh with sockets, not so much!
	import std.datetime : msecs;
	Instance.current.eventLoop.manager.setSourceTimeout(30.msecs);
	aWindowTest();
	Instance.current.eventLoop.execute();

	return 0;
}

import cf.spew.streams.defs;
managed!IStreamEndpoint tcpClientEndPoint;
managed!IStreamServer tcpServer;

void aSocketTCPClientCreate() {
	import std.socket : InternetAddress;
	import std.stdio : write, stdout;
	
	auto streamCreator = Instance.current.streams.createStream(StreamType.TCP);
	streamCreator.onData = (client, data) {
		write(cast(string)data); stdout.flush;
		return true;
	};
	streamCreator.onStreamCreate = (client) { client.write(cast(ubyte[])"
GET / HTTP/1.1\r
Host: cattermole.co.nz\r
\r
\r\n"[1 .. $]); };
	tcpClientEndPoint = streamCreator.connectClient(new InternetAddress("cattermole.co.nz", 80));
}

void aSocketTCPServerCreate() {
	import std.socket : InternetAddress;
	import std.stdio : write, stdout;

	auto streamCreator = Instance.current.streams.createStream(StreamType.TCP);
	streamCreator.onData = (client, data) {
		client.write(data);
		write(cast(string)data);stdout.flush;
		return true;
	};
	tcpServer = streamCreator.bindServer(new InternetAddress("127.0.0.1", 50968));
}

import cf.spew.bindings.opengl;
import cf.spew.ui;
GL* gl;
OpenGL_Loader!OpenGL_Context_Callbacks oglLoader; // global becuase of unload order
bool openglContextCreated, openglObjectsCreated;
GLuint vertexShaderGL, fragmentShaderGL, programGL, vertexbufferGL, vertexArrayGL;
GLint resultGL, infoLogLengthGL;
IWindow window;

float[] opengl_example_vertex_bufferdata = [
	-1.0f, -1.0f, 0.0f,
	1.0f, -1.0f, 0.0f,
	0.0f,  1.0f, 0.0f
];

string VertexShaderGL_Source = "
#version 330 core
layout(location = 0) in vec3 pos;

void main() {
	gl_Position.xyz = pos;
	gl_Position.w = 1.0;
}
\0";

string FragmentShaderGL_Source = "
#version 330 core
out vec3 color;

void main() {
  color = vec3(1,0,0);
}
\0";

void aWindowTest() {
	import cf.spew.events.windowing;
	import cf.spew.instance;
	import std.experimental.memory.managed;
	import std.stdio : writeln, stdout;

	auto creator = Instance.current.ui.createWindow();
	//creator.style = WindowStyle.Fullscreen;
	//creator.size = vec2!ushort(cast(short)800, cast(short)600);
	creator.assignMenu;

	version(all) {
		gl = new GL;
		oglLoader = OpenGL_Loader!OpenGL_Context_Callbacks(gl);
		creator.assignOpenGLContext(OpenGLVersion(3, 2), &oglLoader.callbacks);
	}

	window = creator.createWindow();
	window.title = "Title!";

	Feature_Window_Menu theMenu = window.menu;
	if (theMenu !is null) {
		Window_MenuItem item = theMenu.addItem();
		item.text = "Hi!";
		item.callback = (Window_MenuItem mi) { writeln("Menu Item Click! ", mi.text); };

		Window_MenuItem sub = theMenu.addItem();
		sub.text = "sub";
		Window_MenuItem subItem = sub.addItem();
		subItem.text = "oh yeah!";
		subItem.callback = (Window_MenuItem mi) { writeln("Boo from: ", mi.text); };
	}

	window.events.onForcedDraw = &onForcedDraw;

	window.windowEvents.onMove = (int x, int y) {
		writeln("onMove: x: ", x, " y: ", y);
		stdout.flush;
	};

	window.windowEvents.onRequestClose = () {
		writeln("onRequestClose");
		stdout.flush;
		return true;
	};

	window.events.onCursorMove = (int x, int y) {
		writeln("onCursorMove: x: ", x, " y: ", y);
		stdout.flush;
	};
	
	window.events.onCursorAction = (CursorEventAction action) {
		writeln("onCursorAction: ", action);
		stdout.flush;
	};
	
	window.events.onKeyEntry = (dchar key, SpecialKey specialKey, ushort modifiers) {
		writeln("onKeyEntry: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
		stdout.flush;

		if (specialKey == SpecialKey.Escape)
			Instance.current.eventLoop.stopAllThreads;
		else if (key == '1')
			window.lockCursorToWindow;
		else if (key == '2')
			window.unlockCursorFromWindow;

		foreach(e; __traits(allMembers, KeyModifiers)) {
			if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
				writeln("\t ", e.stringof);
		}
	};

	window.windowEvents.onKeyPress = (dchar key, SpecialKey specialKey, ushort modifiers) {
		writeln("onKeyPress: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
		stdout.flush;
		
		if (specialKey == SpecialKey.Escape)
			Instance.current.eventLoop.stopAllThreads;
		else if (key == '1')
			window.lockCursorToWindow;
		else if (key == '2')
			window.unlockCursorFromWindow;
		
		foreach(e; __traits(allMembers, KeyModifiers)) {
			if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
				writeln("\t ", e.stringof);
		}
	};
	
	window.windowEvents.onKeyRelease = (dchar key, SpecialKey specialKey, ushort modifiers) {
		writeln("onKeyRelease: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
		stdout.flush;
		
		foreach(e; __traits(allMembers, KeyModifiers)) {
			if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
				writeln("\t ", e.stringof);
		}
	};

	window.events.onScroll = (int amount) {
		writeln("onScroll: ", amount);
		stdout.flush;
	};
	
	window.events.onClose = () {
		writeln("onClose");
		stdout.flush;
		Instance.current.eventLoop.stopAllThreads;
	};

	window.events.onSizeChange = (uint width, uint height) {
		writeln("onSizeChange: ", width, "x", height);

		if (window.context.capableOfOpenGL && window.context.readyToBeUsed) {
			window.context.activate;

			gl.glViewport(0, 0, width, height);

			window.context.deactivate;
		}
	};
	
	window.show();

	Instance.current.eventLoop.manager.addSources(new shared ASource);
	Instance.current.eventLoop.execute();
}

final class ASource : EventLoopSource, EventLoopSourceRetriever {
	import std.datetime : StopWatch, Duration;

	StopWatch stopWatch;

	@property {
		bool onMainThread() shared { return true; }
		bool onAdditionalThreads() shared { return true; }
		string description() shared { return "ASource"; }
		EventSource identifier() shared { return EventSource.from("asrc"); }
	}

	shared(EventLoopSourceRetriever) nextEventGenerator(shared(ISharedAllocator)) shared { return this; }

	bool nextEvent(ref Event event) shared {
		import std.stdio;writeln("====TICK====");

		StopWatch* sw = cast(StopWatch*)&stopWatch;
		if (!sw.running)
			sw.start;

		if ((cast(Duration)sw.peek()).total!"msecs" >= 16) {
			onForcedDraw();
			sw.reset;
		}
		return false;
	}
	void handledEvent(ref Event event) shared {}
	void unhandledEvent(ref Event event) shared {}
	void handledErrorEvent(ref Event event) shared {}
	void hintTimeout(Duration timeout) shared {}
}

void onForcedDraw() {
	import std.stdio : writeln, stdout;
	import std.experimental.graphic.image.manipulation.base : fillOn;
	import std.experimental.graphic.color : RGBA8;

	writeln("onForcedDraw");stdout.flush;
	window.context.activate;

	if (!window.context.readyToBeUsed)
		return;

	if (window.context.capableOfVRAM) {
		auto buffer = window.context.vramAlphaBuffer;
		buffer.fillOn(RGBA8(255, 0, 0, 255));
	} else if (window.context.capableOfOpenGL) {
		if (!openglContextCreated) {
			gl.glGenVertexArrays(1, &vertexArrayGL);
			gl.glBindVertexArray(vertexArrayGL);
			
			gl.glGenBuffers(1, &vertexbufferGL);
			gl.glBindBuffer(GL_ARRAY_BUFFER, vertexbufferGL);
			gl.glBufferData(GL_ARRAY_BUFFER, opengl_example_vertex_bufferdata.length*float.sizeof, opengl_example_vertex_bufferdata.ptr, GL_STATIC_DRAW);

			openglContextCreated = true;
		} else if (!openglObjectsCreated) {
			char* source = cast(char*)VertexShaderGL_Source.ptr;
			
			vertexShaderGL = gl.glCreateShader(GL_VERTEX_SHADER);
			gl.glShaderSource(vertexShaderGL, 1, &source, null);
			gl.glCompileShader(vertexShaderGL);
			
			gl.glGetShaderiv(vertexShaderGL, GL_COMPILE_STATUS, &resultGL);
			gl.glGetShaderiv(vertexShaderGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);
			
			if (resultGL == GL_FALSE) {
				char[] log;
				log.length = infoLogLengthGL+1;
				gl.glGetShaderInfoLog(vertexShaderGL, infoLogLengthGL, null, log.ptr);
				writeln("onForcedDraw OGL vertex fail: ", log[0 .. $-1]);
				return;
			}

			source = cast(char*)FragmentShaderGL_Source.ptr;
			
			fragmentShaderGL = gl.glCreateShader(GL_FRAGMENT_SHADER);
			gl.glShaderSource(fragmentShaderGL, 1, &source, null);
			gl.glCompileShader(fragmentShaderGL);
			
			gl.glGetShaderiv(fragmentShaderGL, GL_COMPILE_STATUS, &resultGL);
			gl.glGetShaderiv(fragmentShaderGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);
			
			if (resultGL == GL_FALSE) {
				char[] log;
				log.length = infoLogLengthGL+1;
				gl.glGetShaderInfoLog(fragmentShaderGL, infoLogLengthGL, null, log.ptr);
				writeln("onForcedDraw OGL fragment fail: ", log[0 .. $-1]);
				return;
			}

			programGL = gl.glCreateProgram();
			gl.glAttachShader(programGL, vertexShaderGL);
			gl.glAttachShader(programGL, fragmentShaderGL);
			gl.glLinkProgram(programGL);
			
			gl.glGetProgramiv(programGL, GL_LINK_STATUS, &resultGL);
			gl.glGetProgramiv(programGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);
			if (resultGL == GL_FALSE) {
				char[] log;
				log.length = infoLogLengthGL+1;
				gl.glGetProgramInfoLog(programGL, infoLogLengthGL, null, log.ptr);
				writeln("onForcedDraw OGL link fail: ", log[0 .. $-1]);
				return;
			}
			
			openglObjectsCreated = true;
		} else {
			gl.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
			gl.glUseProgram(programGL);
			gl.glBindVertexArray(vertexArrayGL);
			
			gl.glEnableVertexAttribArray(0);
			gl.glBindBuffer(GL_ARRAY_BUFFER, vertexbufferGL);
			gl.glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
			gl.glDrawArrays(GL_TRIANGLES, 0, 3);
			gl.glDisableVertexAttribArray(0);
			
			/+
			gl.glDetachShader(programGL, vertexShaderGL);
			gl.glDetachShader(programGL, fragmentShaderGL);
			gl.glDeleteProgram(programGL);
			gl.glDeleteShader(vertexShaderGL);
			gl.glDeleteShader(fragmentShaderGL);+/
		}
	}

	window.context.deactivate;
}

