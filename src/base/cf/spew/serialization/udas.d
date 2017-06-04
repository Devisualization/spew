module cf.spew.serialization.udas;

struct ChooseUnionValue {
	ulong theUnionId;
}

struct Union {
	ulong theUnionId;
}

struct UnionValueMap {
	bool isBool, isInitialized;

	union {
		bool b;
		ulong v;
	}

	this(bool v) {
		isBool = true;
		isInitialized = true;
		this.b = v;
	}

	this(ulong v) {
		isInitialized = true;
		this.v = v;
	}
}

struct Name {
	string value;
}

struct Ignore {}

/+bool getFirstUDAOrDefault(Type, string name, UDA)(ref UDA got, UDA default_ = UDA.init) pure
if (is(UDA == struct) || is(UDA==string)) {
	import std.traits : getUDAs, hasUDA;

	static if (hasUDA!(symbol, UDA)) {
		auto udas = getUDAs!(symbol, UDA);

		if (udas.length > 0) {
			got = udas[0];
			return true;
		}
	}

	got = default_;
	return false;
}+/