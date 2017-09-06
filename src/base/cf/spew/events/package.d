///
module cf.spew.events;
public import cf.spew.events.defs;
public import cf.spew.events.windowing;

///
version(Windows) {
	///
	public import cf.spew.events.winapi;
}