module cf.spew.serialization.defs;
import std.variant : Variant;
import std.system : Endian;
import std.experimental.allocator : IAllocator;

enum Type {
	Bool,
	UByte, Byte,
	UShort, Short,
	UInt, Int,
	ULong, Long,
	Float, Double,
	Array, Enum,
	StringUTF8, StringUTF16, StringUTF32,
	Struct, Object
}

interface IArchiver {
	void reset();
	void setEndianess(Endian);

	//

	bool retrieveBool();
	byte retrieveByte();
	ubyte retrieveUByte();
	short retrieveShort();
	ushort retrieveUShort();
	int retrieveInt();
	uint retrieveUInt();
	long retrieveLong();
	ulong retrieveULong();
	float retrieveFloat();
	double retrieveDouble();
	string retrieveStringUTF8();
	wstring retrieveStringUTF16();
	dstring retrieveStringUTF32();

	//

	void storeBool(bool);
	void storeByte(byte);
	void storeUByte(ubyte);
	void storeShort(short);
	void storeUShort(ushort);
	void storeInt(int);
	void storeUInt(uint);
	void storeLong(long);
	void storeULong(ulong);
	void storeFloat(float);
	void storeDouble(double);
	void storeStringUTF8(string);
	void storeStringUTF16(wstring);
	void storeStringUTF32(dstring);

	//

	void symbolName(string);
	void beginContainer(Type t, TypeInfo);
	void endContainer();
	size_t containerSize();
}

bool isArchiver(T)() pure {
	static if (is(T : IArchiver)) {
		return true;
	} else {
		return __traits(compiles, {
				T t;
				t.reset();
				t.setEndian(Endian.littleEndian);

				t.beginContainer(Type.Int, typeid(int[]));
				t.endContainer();

				t.symbolName("abc");
				size_t vcs = t.containerSize();

				bool v1 = t.retrieveBool();
				byte v2 = t.retrieveByte();
				ubyte v3 = t.retrieveUByte();
				short v4 = t.retrieveShort();
				ushort v5 = t.retrieveUShort();
				int v6 = t.retrieveInt();
				uint v7 = t.retrieveUInt();
				long v8 = t.retrieveLong();
				ulong v9 = t.retrieveULong();
				float v10 = t.retrieveFloat();
				double v11 = t.retrieveDouble();
				string v12 = t.retrieveStringUTF8();
				wstring v13 = t.retrieveStringUTF16();
				dstring v14 = t.retrieveStringUTF32();

				t.storeBool(true);
				t.storeByte(byte.min);
				t.storeUByte(ubyte.max);
				t.storeShort(short.min);
				t.storeUShort(ushort.max);
				t.storeInt(int.min);
				t.storeUInt(uint.max);
				t.storeLong(long.min);
				t.storeULong(ulong.max);
				t.storeFloat(float.infinity);
				t.storeDouble(double.infinity);
				t.storeStringUTF8("abc");
				t.storeStringUTF16("abc"w);
				t.storeStringUTF32("abc"d);
			});
	}
}

interface ISerializer {
	void addTypeReflector(TypeReflector handlers, bool replace=false);
	void setAllocator(IAllocator);
	void reset();

	void setArchiver(IArchiver);
	IArchiver getArchiver();

	void serialize(Variant, bool withObjectHierarchyLookup=true);
	Variant deserialize(TypeInfo, bool withObjectHierarchyLookup=true);
}

bool isSerializer(T)() pure {
	static if (is(T : ISerializer)) {
		return true;
	} else {
		return __traits(compiles, {
				import std.experimental.allocator : theAllocator;

				T t;
				t.addTypeReflector(TypeReflector(), true);

				t.setAllocator(theAllocator());
				t.reset();

				t.setArchiver(new AnArchiver);
				IArchiver archiver = t.getArchiver();

				t.serialize(Variant(9));
				Variant v = t.deserialize(typeid(int));
			});
	}
}



void serialize(T, Ctx)(ref Ctx ctx, ref T value, bool withObjectHierarchyLookup=true) if (isSerializer!Ctx) {
	ctx.serialize(Variant(value), withObjectHierarchyLookup);
}

T deserialize(T, Ctx)(ref Ctx ctx, bool withObjectHierarchyLookup) if (isSerializer!Ctx) {
	return ctx.deserialize(typeid(T), withObjectHierarchyLookup).get!T;
}

interface ISerializable {
	void serialize(void delegate(Variant) serializer, IArchiver archiver);
	static void deserialize(Variant delegate(TypeInfo) deserializer, IArchiver archiver, IAllocator alloc, out ISerializable ret);
}

bool isSerializableCustom(T)() pure {
	static if (is(T : ISerializable)) {
		return true;
	} else {
		return __traits(compiles, {
				import std.experimental.allocator : theAllocator;

				T t;
				t.serialize((Variant) {}, new AnArchiver);

				ISerializable got;
				T.deserialize((Type) { return Variant(1); }, new AnArchiver, theAllocator(), got);
			});
	}
}

struct TypeReflector {
	Type type;
	TypeInfo typeInfo;
	
	void function(Variant, IArchiver, void delegate(Variant) nextToSerialize) fromType;
	Variant function(IArchiver, IAllocator, Variant delegate(TypeInfo) nextToDeserialize) toType;
}

class TypeNotSerializable : Exception {
	@nogc @safe pure nothrow this(string msg, string file=__FILE__, size_t line=__LINE__) {
		super(msg, file, line);
	}
}

private {
	class AnArchiver : IArchiver {
		void reset() {}
		void setEndianess(Endian) {}
		
		//
		
		bool retrieveBool() { assert(0); }
		byte retrieveByte() { assert(0); }
		ubyte retrieveUByte() { assert(0); }
		short retrieveShort() { assert(0); }
		ushort retrieveUShort() { assert(0); }
		int retrieveInt() { assert(0); }
		uint retrieveUInt() { assert(0); }
		long retrieveLong() { assert(0); }
		ulong retrieveULong() { assert(0); }
		float retrieveFloat() { assert(0); }
		double retrieveDouble() { assert(0); }
		string retrieveStringUTF8() { assert(0); }
		wstring retrieveStringUTF16() { assert(0); }
		dstring retrieveStringUTF32() { assert(0); }
		
		//
		
		void storeBool(bool) {}
		void storeByte(byte) {}
		void storeUByte(ubyte) {}
		void storeShort(short) {}
		void storeUShort(ushort) {}
		void storeInt(int) {}
		void storeUInt(uint) {}
		void storeLong(long) {}
		void storeULong(ulong) {}
		void storeFloat(float) {}
		void storeDouble(double) {}
		void storeStringUTF8(string) {}
		void storeStringUTF16(wstring) {}
		void storeStringUTF32(dstring) {}
		
		//
		
		void beginContainer(Type t, TypeInfo) {}
		void endContainer() {}
		size_t containerSize() { assert(0); }
		void symbolName(string) {}
	}
}