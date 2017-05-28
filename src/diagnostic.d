module diagnostic;

import cf.spew.serialization.base;
import cf.spew.serialization.base_type_reflectors;

int main() {
	import cf.spew.instance;

	version(none) {
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

		aWindowTest();
	}

	return 0;
}

void aWindowTest() {
	import cf.spew.ui;
	import cf.spew.events.windowing;
	import cf.spew.instance;
	import std.experimental.graphic.image.manipulation.base : fillOn;
	import std.experimental.allocator;
	import std.experimental.memory.managed;
	import std.experimental.graphic.color : RGBA8;
	import std.stdio : writeln, stdout;

	IWindow window;

	auto creator = Instance.current.ui.createWindow();
	//creator.style = WindowStyle.Fullscreen;
	//creator.size = vec2!ushort(cast(short)800, cast(short)600);

	window = creator.createWindow();
	window.title = "Title!";
	
	window.events.onForcedDraw = () {
		window.context.activate;
		auto buffer = window.context.vramAlphaBuffer;

		writeln("onForcedDraw");
		stdout.flush;
		buffer.fillOn(RGBA8(255, 0, 0, 255));

		window.context.deactivate;
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
	
	window.show();

	import std.datetime : seconds;
	Instance.current.eventLoop.manager.setSourceTimeout(3.seconds);
	Instance.current.eventLoop.manager.addSources(new ASource);
	Instance.current.eventLoop.execute();
}

import cf.spew.event_loop.defs;
final class ASource : EventLoopSource, EventLoopSourceRetriever {
	@property {
		bool onMainThread() { return true; }
		bool onAdditionalThreads() { return true; }
		string description() { return "ASource"; }
		EventSource identifier() { return EventSource.from("asrc"); }
	}

	EventLoopSourceRetriever nextEventGenerator(IAllocator) { return this; }

	bool nextEvent(ref Event event) {
		import std.stdio;writeln("====TICK====");
		return false;
	}
	void handledEvent(ref Event event) {}
	void unhandledEvent(ref Event event) {}
	void handledErrorEvent(ref Event event) {}
	void hintTimeout(Duration timeout) {}
}