module cf.spew.serialization.base_type_reflectors;
import cf.spew.serialization.defs;
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
	
	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
		mixin("archiver." ~ Store ~ "(v.get!T);");
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
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

	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
		archiver.beginContainer(type, typeid(U));

		T array = v.get!T;
		foreach(ref va; array) {
			nextToSerialize(Variant(va));
		}

		archiver.endContainer();
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
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

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
			archiver.storeStringUTF8(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
			return Variant(archiver.retrieveStringUTF8());
		};

		ctx.addTypeReflector(reflector, replace);
	} else static if (is(U == wchar)) {
		TypeReflector reflector = TypeReflector(Type.StringUTF16, typeid(U[]));

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
			archiver.storeStringUTF16(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
			return Variant(archiver.retrieveStringUTF16());
		};

		ctx.addTypeReflector(reflector, replace);
	} else static if (is(U == dchar)) {
		TypeReflector reflector = TypeReflector(Type.StringUTF32, typeid(U[]));

		reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
			archiver.storeStringUTF32(cast(T)v.get!(U[]));
		};
		reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
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
	
	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant, bool withObjectHierarchyLookup=true) nextToSerialize) {
		mixin("nextToSerialize(Variant(cast(O)v.get!T));");
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo, bool withObjectHierarchyLookup=true) nextToDeserialize) {
		return nextToDeserialize(typeid(O));
	};
	
	ctx.addTypeReflector(reflector, replace);
}