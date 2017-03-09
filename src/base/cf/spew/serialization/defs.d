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

				// TODO
			});
	}
}

interface ISerializer {
	void addTypeReflector(TypeReflector handlers, bool replace=false);
	void setAllocator(IAllocator);
	void reset();

	void setArchiver(IArchiver);
	IArchiver getArchiver();

	void serialize(Variant);
	Variant deserialize(TypeInfo);
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

				class AnArchiver : IArchiver {
					void reset() {}
					void setEndianess(Endian) {}
				}
				t.setArchiver(new AnArchiver);
				IArchiver archiver = t.getArchiver();

				t.serialize(Variant(9));
				Variant v = t.deserialize(typeid(int));
			});
	}
}

void serialize(T, Ctx)(ref Ctx ctx, ref T value) if (isSerializer!Ctx) {
	ctx.serialize(Variant(value));
}

T deserialize(T, Ctx)(ref Ctx ctx) if (isSerializer!Ctx) {
	return ctx.deserialize(typeid(T)).get!T;
}

interface ISerializable {
	void serialize(void delegate(Variant) serializer, IArchiver archiver);
	void deserialize(Variant delegate(Type) deserializer, IArchiver archiver, out ISerializable ret);
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