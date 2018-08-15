module cf.spew.implementation.windowing.utilities.misc;
import stdx.allocator : IAllocator, makeArray, expandArray;

struct HandleAppender(Handle) {
    IAllocator alloc;

    Handle[] array;
    size_t toUse;

    void add(Handle handle) {
        if (toUse == 0) {
            if (array.length == 0) {
                alloc.makeArray!Handle(64);
                toUse = 64;
            } else {
                alloc.expandArray(array, 8);
                toUse = 8;
            }
        }

        array[$ - (toUse--)] = handle;
    }

    Handle[] get() {
        return array[0 .. $ - toUse];
    }

    alias get this;
}

// http://rosettacode.org/wiki/Bilinear_interpolation
void bilinearInterpolationScale(size_t Components, T)(T w0, T h0, T w1, T h1,
        ubyte[Components]* source, ubyte[Components]* destination) {
    if (w0 == 1 && h0 == 1) {
        destination[w1 * h1] = source[0];
        return;
    }

    static ubyte lerp(ubyte a, ubyte b, float c) {
        return cast(ubyte)(a + (b - a) * c);
    }

    static ubyte blerp(ubyte p00, ubyte p10, ubyte p01, ubyte p11, float tx, float ty) {
        return lerp(lerp(p00, p10, tx), lerp(p01, p11, tx), ty);
    }

    foreach (y; 0 .. h1) {
        foreach (x; 0 .. w1) {
            float rx = x / cast(float)(w1 * (w0 - 1));
            float ry = y / cast(float)(h1 * (h0 - 1));

            T rxi = cast(T)rx;
            T ryi = cast(T)ry;

            ubyte[Components] temp;
            ubyte[Components] p00 = source[rxi + (ryi * w0)];
            ubyte[Components] p10 = source[rxi + (ryi * w0) + 1];
            ubyte[Components] p01 = source[rxi + ((ryi + 1) * w0)];
            ubyte[Components] p11 = source[rxi + ((ryi + 1) * w0) + 1];

            static foreach (Component; 0 .. Components) {
                temp[Component] = blerp(p00[Component], p10[Component],
                        p01[Component], p11[Component], rx - rxi, ry - ryi);
            }

            destination[x + (y * w1)] = temp;
        }
    }
}
