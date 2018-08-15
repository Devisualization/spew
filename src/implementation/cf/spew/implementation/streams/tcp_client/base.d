module cf.spew.implementation.streams.tcp_client.base;
import cf.spew.implementation.streams.base;
import cf.spew.streams.defs;
import cf.spew.streams.tcp;
import stdx.allocator : IAllocator;

abstract class AnTCPSocket : StreamPoint, ISocket_TCP {
    package(cf.spew.implementation) {
        ISocket_TCPServer server_;
        IAllocator alloc;
    }

    @property {
        ISocket_TCPServer server() {
            return server_;
        }

        // *sigh* just why is this required?
        override void onConnect(OnStreamConnectedDel callback) {
            onStreamConnectedDel = callback;
        }
    }
}
