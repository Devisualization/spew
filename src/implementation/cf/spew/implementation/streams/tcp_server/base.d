module cf.spew.implementation.streams.tcp_server.base;
import cf.spew.implementation.streams.base;
import cf.spew.streams.tcp;

abstract class AnTCPServer : StreamPoint, ISocket_TCPServer {
    package(cf.spew.implementation) {
        ushort listBacklogAmount_ = 128;
    }
}
