module diagnostic;

int main() {
	import cf.spew.instance;

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
		writeln(" or have a look on newsgroup! http://forum.dlang.org/group/announce");

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

	return 0;
}