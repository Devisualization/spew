module cf.spew.serialization.udas;

struct ChooseUnionValue {
	ulong theUnionId;
}

struct Union {
	ulong theUnionId;
}

struct UnionValueMap {
	long value;
}

struct Name {
	string value;
}

struct Ignore {}
