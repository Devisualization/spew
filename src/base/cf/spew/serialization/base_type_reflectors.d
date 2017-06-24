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

	TypeReflector reflector = TypeReflector(Type.Array, typeid(U[]));

	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		archiver.beginContainer(Type.Array, typeid(U));

		T array = v.get!T;
		foreach(ref va; array) {
			nextToSerialize(Variant(va));
		}

		archiver.endContainer();
	};
	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		archiver.beginContainer(Type.Array, typeid(U));

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

void addType(T, Ctx)(ref Ctx ctx, bool replace=false) if (isSerializer!Ctx &&
	(is(T == class) || is(T == struct))) {
	alias O = Unqual!T;

	static if (is(T == class)) {
		enum Type type = Type.Object;
	} else static if (is(T == struct)) {
		enum Type type = Type.Struct;
	}

	TypeReflector reflector = TypeReflector(type, typeid(O));
	static assert(isFieldDescriptionValid!O);

	reflector.fromType = (Variant v, IArchiver archiver, void delegate(Variant) nextToSerialize) {
		T input = cast(T)v.get!O;
		archiver.beginContainer(type, typeid(O));

		static if (isSerializableCustom!O) {
			input.serialize(nextToSerialize, archiver);
		} else {
			enum allFields = DescribeFields!O;
			foreach(i, fieldV; allFields) {

				// top \/

				static if (fieldV.varNames.length > 0) {
					static if (fieldV.varNames.length == 1) {
						archiver.symbolName(fieldV.prefferedVarNames[0]);
						nextToSerialize(Variant(mixin("input." ~ fieldV.varNames[0])));
					} else {
						// > 1
						static assert(fieldV.theUnionChooserIndex >= 0);
						// chooser < us
						static assert(fieldV.theUnionChooserIndex <= fieldV.offset);

						mixin("long chooser = cast(long)input." ~ allFields[fieldV.theUnionChooserIndex].varNames[0] ~ ";");

						// if we don't match, what is it to us?
						// not our problem..
						foreach(i, vm; fieldV.varMaps) {
							if (vm.value == chooser) {
								archiver.symbolName(fieldV.prefferedVarNames[i]);
								nextToSerialize(Variant(mixin("input." ~ fieldV.varNames[i])));
								break;
							}
						}
					}
				}

				// bottom /\

			}
		}

		archiver.endContainer();
	};

	reflector.toType = (IArchiver archiver, IAllocator alloc, Variant delegate(TypeInfo) nextToDeserialize) {
		O ret = void;

		static if (is(O == class)) {
			import std.experimental.allocator : make;
			ret = alloc.make!O;
		}

		archiver.beginContainer(type, typeid(O));
		
		static if (isSerializableCustom!O) {
			O.deserialize(nextToDeserialize, archiver, alloc, ret);
		} else {
			enum allFields = DescribeFields!O;
			foreach(i, fieldV; allFields) {

				// top \/
				
				static if (fieldV.varNames.length > 0) {
					static if (fieldV.varNames.length == 1) {
						archiver.symbolName(fieldV.prefferedVarNames[0]);
						mixin("ret." ~ fieldV.varNames[0] ~ ` = nextToDeserialize(typeid(mixin("O." ~ fieldV.varNames[0])));`);
					} else {
						// > 1
						static assert(fieldV.theUnionChooserIndex >= 0);
						// chooser < us
						static assert(fieldV.theUnionChooserIndex <= fieldV.offset);

						mixin("long chooser = cast(long)input." ~ allFields[fieldV.theUnionChooserIndex].varNames[0] ~ ";");
						
						// if we don't match, what is it to us?
						// not our problem..
						foreach(i, vm; fieldV.varMaps) {
							if (vm.value == chooser) {
								archiver.symbolName(fieldV.prefferedVarNames[i]);
								ret = mixin("ret." ~ fieldV.varNames[i] ~ ` = nextToDeserialize(typeid(mixin("O." ~ fieldV.varNames[0])));`);
								break;
							}
						}
					}
				}

				// bottom /\

			}
		}
		
		archiver.endContainer();
		return Variant(ret);
	};

	ctx.addTypeReflector(reflector, replace);
}

bool isFieldDescriptionValid(T)() pure {
	import std.traits : isIntegral, OriginalType;

	foreach(field; DescribeFields!T) {
		static if (field.unionIdChooser >= 0 && field.varNames.length > 1) {
			// I'm lazy, so lets not support id -> union id -> union
			return false;
		} else static if (field.unionIdChooser >= 0) {
			static if (field.theUnionIndex < field.offset) {
				// #lazy, union chooser comes /before/ the union! duh
				return false;
			}else static if (field.varNames.length == 1) {
				alias OType = OriginalType!(typeof(mixin("T." ~ field.varNames[0])));
				static if (!(isIntegral!(OType) || is(OType == bool))) {
					return false;
				}
			} else static if (field.varNames.length != 1) {
				return false;
			}
		}
	}

	return true;
}

template DescribeFields(T) {
	enum DescribeFields = {
		enum Data = {
			import std.traits : Fields, FieldNameTuple, hasUDA, getUDAs;

			DescribeFieldsElement[] ret;
			
			alias AllFields = Fields!T;
			alias AllFieldNames = FieldNameTuple!T;
			
			uint lastOffset, lastOffsetV;
			long lastUnionId = -1;
			foreach(name; AllFieldNames) {
				static if (name.length > 0) {
					mixin("enum Offset = T." ~ name ~ ".offsetof;");
					
					static if (hasUDA!(__traits(getMember, T, name), Ignore))
						continue;
					else {
						if (ret.length == 0 || lastOffset != Offset) {
							if (ret.length > 0 && ret[$-1].unionId >= 0) {
								lastUnionId = ret[$-1].unionId;
							}
							
							ret ~= DescribeFieldsElement([name], [name], [], lastOffsetV);
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
							ret[$-1].preferredVarNames ~= name;
						}

						static if (hasUDA!(__traits(getMember, T, name), UnionValueMap)) {
							alias UDAS = getUDAs!(__traits(getMember, T, name), UnionValueMap);
							
							static if (UDAS.length >= 1) {
								ret[$-1].varMaps.length = ret[$-1].varNames.length;
								ret[$-1].varMaps[$-1] = UDAS[0];
							}
						}

						static if (hasUDA!(__traits(getMember, T, name), Name)) {
							alias UDAS = getUDAs!(__traits(getMember, T, name), Name);
							
							static if (UDAS.length >= 1) {
								ret[$-1].preferredVarNames[$-1] = UDAS[0].value;
							}
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
		}();

		string creator() pure {
			import std.conv : text;
			string ret = "tuple(";
			foreach(i; 0 .. Data.length) {
				if (i > 0)
					ret ~= ", ";
				ret ~= "Data[" ~ i.text ~ "]";
			}
			return ret ~ ")";
		}

		import std.typecons;
		return mixin(creator());
	}();
}

private {
	struct DescribeFieldsElement {
		string[] varNames, preferredVarNames;
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

	struct DescribeFieldsTest3 {
		@Ignore
		int z;
		@ChooseUnionValue(0)
		uint type;
		Object o;
		
		@Union(0)
		SubU u;
		
		union SubU {
			@UnionValueMap(0)
			uint x;
			union {
				@UnionValueMap(1)
				int y;
				@UnionValueMap(2)
				bool w;
			}
		}
		
		short s;
	}

	shared static this() {
		import std.stdio;

		void describe(T)() {
			static assert(isFieldDescriptionValid!T);
			foreach(v; DescribeFields!T) {
				writeln("- ", v.offset);
				writeln("\t varNames:", v.varNames);
				
				writeln("\t varMaps:");
				foreach(ref vm; v.varMaps) {
					writeln("\t\t- ", vm.value);
				}
				
				writeln("\t unionId:", v.unionId);
				writeln("\t unionIdChooser:", v.unionIdChooser);
				writeln("\t theUnionChooserIndex:", v.theUnionChooserIndex);
				writeln("\t theUnionIndex:", v.theUnionIndex);
			}
		}

		writeln("DescribeFieldsTest1");
		describe!DescribeFieldsTest1;

		writeln("DescribeFieldsTest2");
		describe!DescribeFieldsTest2;

		writeln("DescribeFieldsTest3");
		describe!DescribeFieldsTest3;
	}
}