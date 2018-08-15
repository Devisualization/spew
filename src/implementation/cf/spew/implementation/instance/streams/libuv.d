module cf.spew.implementation.instance.streams.libuv;
import cf.spew.implementation.instance.streams.base;
import cf.spew.streams;
import devisualization.util.core.memory.managed;
import std.socket : Address, InternetAddress, Internet6Address;
import stdx.allocator : ISharedAllocator, IAllocator, make, makeArray,
    theAllocator;

final class StreamsInstance_LibUV : StreamsInstance {
    this(shared(ISharedAllocator) allocator) shared {
        super(allocator);
    }

    managed!ISocket_TCPServer tcpServer(Address address,
            ushort listBacklogAmount = 64, IAllocator alloc = theAllocator()) shared {
        import cf.spew.implementation.streams.tcp_server.libuv : LibUVTCPServer;

        return LibUVTCPServer.create(address, listBacklogAmount, alloc);
    }

    managed!ISocket_TCP tcpConnect(Address address, IAllocator alloc = theAllocator()) shared {
        import cf.spew.implementation.streams.tcp_client.libuv : LibUVTCPSocket;

        return LibUVTCPSocket.create(address, alloc);
    }

    managed!ISocket_UDPLocalPoint udpLocalPoint(Address address, IAllocator alloc = theAllocator()) shared {
        import cf.spew.implementation.streams.udp.libuv : LibUVUDPLocalPoint;

        return LibUVUDPLocalPoint.create(address, alloc);
    }

    managed!(managed!Address[]) allLocalAddress(IAllocator alloc = theAllocator()) shared {
        import devisualization.bindings.libuv;

        if (alloc is null)
            return managed!(managed!Address[]).init;

        managed!Address[] ret;

        int count;
        uv_interface_address_t* addresses;
        libuv.uv_interface_addresses(&addresses, &count);

        ret = cast(managed!Address[])alloc.makeArray!(ubyte)(count * managed!Address.sizeof);
        foreach (i, v; addresses[0 .. count]) {
            if (v.address.address4.sin_family == AF_INET) {
                ret[i] = cast(managed!Address)managed!InternetAddress(
                        alloc.make!InternetAddress(v.address.address4), managers(), alloc);
            } else if (v.address.address4.sin_family == AF_INET6) {
                ret[i] = cast(managed!Address)managed!Internet6Address(
                        alloc.make!Internet6Address(v.address.address6), managers(), alloc);
            } else {
                ret[i] = managed!Address.init;
            }
        }

        libuv.uv_free_interface_addresses(addresses, count);
        return managed!(managed!Address[])(ret, managers(), alloc);
    }
}
