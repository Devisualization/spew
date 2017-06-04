module cf.spew.serialization.base_type_reflectors;
import cf.spew.serialization.defs;
import cf.spew.serialization.udas;
import std.variant : Variant;
import std.traits : isBasicType, isDynamicArray, ForeachType, isNarrowString, Unqual, OriginalType;
import std.experimental.allocator : IAllocator, makeArray;

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx && isBasicType!T && !is(T == enum)) {
	import std.uni : toUpper;

	alias O = Unqual!T;

	static if (O.stringof[0] == 'u') {
		enum Store = "store" ~ O.stringof[0 .. 2].toUpper ~ O.stringof[2 .. $];
		enum Retrieve = "retrieve" ~ O.stringof[0 .. 2].toUpper ~ O.stringof[2 .. $];
		enum type = mixin("Type." ~ O.stringof[0 .. 2].toUpper ~ O.stringof[2 .. $]);
	} else {
		enum Store = "store" ~ (cast(string)[O.stringof[0].toUpper]) ~ O.stringof[1 .. $];
		enum Retrieve = "retrieve" ~ (cast(string)[O.stringof[0].toUpper]) ~ O.stringof[1 .. $];
		enum type = mixin("Type." ~ (cast(string)[O.stringof[0].toUpper]) ~ O.stringof[1 .. $]);
	}

	TypeReflector reflector = TypeReflector(type, typeid(O));
	
	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		mixin("archiver." ~ Store ~ "(v.get!T);");
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		mixin("return Variant(archiver." ~ Retrieve ~ "());");
	};

	ctx.addTypeReflector(reflector, replace);
}

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx && isDynamicArray!T && !(
		is(Unqual!(ForeachType!T) == char) ||
		is(Unqual!(ForeachType!T) == wchar) ||
		is(Unqual!(ForeachType!T) == dchar))) {

	alias O = Unqual!T;
	alias U = Unqual!(ForeachType!O);

	static if (is(U == bool)) {
		enum type = Type.Bool;
	} else static if (is(U == ubyte)) {
		enum type = Type.UByte;
	} else static if (is(U == byte)) {
		enum type = Type.Byte;
	} else static if (is(U == ushort)) {
		enum type = Type.UShort;
	} else static if (is(U == short)) {
		enum type = Type.Short;
	} else static if (is(U == uint)) {
		enum type = Type.UInt;
	} else static if (is(U == int)) {
		enum type = Type.Int;
	} else static if (is(U == ulong)) {
		enum type = Type.ULong;
	} else static if (is(U == long)) {
		enum type = Type.Long;
	} else static if (is(U == float)) {
		enum type = Type.Float;
	} else static if (is(U == double)) {
		enum type = Type.Double;
	} else static if (is(U == struct)) {
		enum type = Type.Struct;
	} else static if (is(U == class) || is(U == interface)) {
		enum type = Type.Object;
	} else {
		static assert(0, "Type " ~ O.stringof ~ " unsupported as an element");
	}

	TypeReflector reflector = TypeReflector(Type.Array, typeid(U[]));

	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		archiver.beginContainer(type, typeid(U));

		T array = v.get!T;
		foreach(ref va; array) {
			nextToSerialize(Variant(va));
		}

		archiver.endContainer();
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		archiver.beginContainer(type, typeid(U));

		size_t len = archiver.containerSize();
		T ret = alloc.makeArray!U(len);

		foreach(i; 0 .. len) {
			ret[i] = nextToDeserialize(typeid(U)).get!U;
		}

		archiver.endContainer();
		return Variant(ret);
	};
	
	ctx.addTypeReflector(reflector, replace);
}

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx && isDynamicArray!T && (
		is(Unqual!(ForeachType!T) == char) ||
		is(Unqual!(ForeachType!T) == wchar) ||
		is(Unqual!(ForeachType!T) == dchar))) {

	alias O = Unqual!T;
	alias U = Unqual!(ForeachType!O);

	static if (is(U == char)) {
		TypeReflector reflector = TypeReflector(Type.StringUTF8, typeid(U[]));

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
			archiver.storeStringUTF8(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
			return Variant(archiver.retrieveStringUTF8());
		};

		ctx.addTypeReflector(reflector, replace);
	} else static if (is(U == wchar)) {
		TypeReflector reflector = TypeReflector(Type.StringUTF16, typeid(U[]));

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
			archiver.storeStringUTF16(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
			return Variant(archiver.retrieveStringUTF16());
		};

		ctx.addTypeReflector(reflector, replace);
	} else static if (is(U == dchar)) {
		TypeReflector reflector = TypeReflector(Type.StringUTF32, typeid(U[]));

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
			archiver.storeStringUTF32(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
			return Variant(archiver.retrieveStringUTF32());
		};

		ctx.addTypeReflector(reflector, replace);
	}
}

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx && is(T == enum)) {
	import std.uni : toUpper;
	alias O = OriginalType!T;
	ctx.addType!O;
	
	TypeReflector reflector = TypeReflector(Type.Enum, typeid(T));
	
	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		mixin("nextToSerialize(Variant(cast(O)v.get!T));");
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		return nextToDeserialize(typeid(O));
	};

	ctx.addTypeReflector(reflector, replace);
}

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx && (is(T == class) || is(T == struct))) {
	alias O = Unqual!T;

	static if (is(T == class)) {
		enum Type type = Type.Object;
	} else static if (is(T == struct)) {
		enum Type type = Type.Struct;
	}

	TypeReflector reflector = TypeReflector(type, typeid(O));

	// TODO: validate for unions

	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		T input = cast(T)v.get!O;
		archiver.beginContainer(type, typeid(O));

		static if (isSerializableCustom!O) {
			input.serialize(&nextToSerialize, archiver);
		} else {

		}

		archiver.endContainer();
	};

	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		O ret = void;
		archiver.beginContainer(type, typeid(O));
		
		static if (isSerializableCustom!O) {
			O.deserialize(&nextToDeserialize, archiver, alloc, ret);
		} else {
			
		}
		
		archiver.endContainer();
		return Variant(ret);
	};

	ctx.addTypeReflector(reflector, replace);
}

auto DescribeFields(T)() pure {
	import std.traits : Fields, FieldNameTuple, hasUDA, getUDAs;

	DescribeFieldsElement[] ret;
	
	alias AllFields = Fields!T;
	alias AllFieldNames = FieldNameTuple!T;
	
	uint lastOffset, lastOffsetV;
	long lastUnionId = -1;
	foreach(name; AllFieldNames) {
		mixin("enum Offset = T." ~ name ~ ".offsetof;");
		
		static if (hasUDA!(__traits(getMember, T, name), Ignore))
			continue;
		else {
			if (ret.length == 0 || lastOffset != Offset) {
				if (ret.length > 0 && ret[$-1].unionId >= 0) {
					lastUnionId = ret[$-1].unionId;
				}
				
				ret ~= DescribeFieldsElement([name], [], lastOffsetV);
				lastOffset = Offset;
				
				static if (hasUDA!(__traits(getMember, T, name), ChooseUnionValue)) {
					alias UDAS = getUDAs!(__traits(getMember, T, name), ChooseUnionValue);
					
					static if (UDAS.length >= 1) {
						ret[$-1].unionIdChooser = UDAS[0].theUnionId;
					}
				}
				
				static if (hasUDA!(__traits(getMember, T, name), Union)) {
					alias UDAS = getUDAs!(__traits(getMember, T, name), Union);
					
					static if (UDAS.length >= 1) {
						assert(lastUnionId >= UDAS[0].theUnionId, "Union id supplied is less then <= previous");
						ret[$-1].unionId = UDAS[0].theUnionId;
					}
				}

				alias ElementType = typeof(__traits(getMember, T, name));
				static if (is(ElementType == union)) {
					auto describer = DescribeFields!ElementType[0];

					ret[$-1].varNames = null;
					ret[$-1].varMaps = describer.varMaps;

					foreach(vn; describer.varNames) {
						ret[$-1].varNames ~= name ~ "." ~ vn;
					}
				}

				lastOffsetV++;
			} else {
				if (ret[$-1].unionId == -1)
					ret[$-1].unionId = lastUnionId+1;
				ret[$-1].varNames ~= name;
			}

			static if (hasUDA!(__traits(getMember, T, name), UnionValueMap)) {
				alias UDAS = getUDAs!(__traits(getMember, T, name), UnionValueMap);
				
				static if (UDAS.length >= 1) {
					ret[$-1].varMaps.length = ret[$-1].varNames.length;
					ret[$-1].varMaps[$-1] = UDAS[0];
				}
			}
		}
	}
	
F1: foreach(i, ref chooser; ret) {
		if (chooser.unionIdChooser >= 0) {
			size_t ciU;
			
			foreach(j, ref theUnion; ret) {
				if (theUnion.varNames.length > 1) {
					if (chooser.unionIdChooser == ciU) {
						theUnion.theUnionChooserIndex = i;
						chooser.theUnionIndex = j;
						continue F1;
					}
					
					ciU++;
				}
			}
		}
	}
	
	return ret;
}

private {
	struct DescribeFieldsElement {
		string[] varNames;
		UnionValueMap[] varMaps;
		
		uint offset;
		long unionId = -1,
			 unionIdChooser = -1;
		uint theUnionChooserIndex, theUnionIndex;
	}

	struct DescribeFieldsTest1 {
		@Ignore
		int z;
		@ChooseUnionValue(0)
		bool type;
		Object o;

		@Union(0)
		union {
			@UnionValueMap(true)
			uint x;
			@UnionValueMap(false)
			string t;
		}

		short s;
	}

	struct DescribeFieldsTest2 {
		@Ignore
		int z;
		@ChooseUnionValue(0)
		bool type;
		Object o;
		
		@Union(0)
		SubU u;

		union SubU {
			@UnionValueMap(true)
			uint x;
			@UnionValueMap(false)
			string t;
		}
		
		short s;
	}

	shared static this() {
		import std.stdio;

		writeln("DescribeFieldsTest1");
		foreach(ref v; DescribeFields!DescribeFieldsTest1()) {
			writeln("- ", v.offset);
			writeln("\t varNames:", v.varNames);

			writeln("\t varMaps:");
			foreach(ref vm; v.varMaps) {
				if (!vm.isInitialized)
					writeln("\t\t- unitialized");
				else if (vm.isBool)
					writeln("\t\t- ", vm.b);
				else if(!vm.isBool)
					writeln("\t\t- ", vm.v);
			}

			writeln("\t unionId:", v.unionId);
			writeln("\t unionIdChooser:", v.unionIdChooser);
			writeln("\t theUnionChooserIndex:", v.theUnionChooserIndex);
			writeln("\t theUnionIndex:", v.theUnionIndex);
		}

		writeln("DescribeFieldsTest2");
		foreach(ref v; DescribeFields!DescribeFieldsTest2()) {
			writeln("- ", v.offset);
			writeln("\t varNames:", v.varNames);

			writeln("\t varMaps:");
			foreach(ref vm; v.varMaps) {
				if (!vm.isInitialized)
					writeln("\t\t- unitialized");
				else if (vm.isBool)
					writeln("\t\t- ", vm.b);
				else if(!vm.isBool)
					writeln("\t\t- ", vm.v);
			}

			writeln("\t unionId:", v.unionId);
			writeln("\t unionIdChooser:", v.unionIdChooser);
			writeln("\t theUnionChooserIndex:", v.theUnionChooserIndex);
			writeln("\t theUnionIndex:", v.theUnionIndex);
		}
	}
}