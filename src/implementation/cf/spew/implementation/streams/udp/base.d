module cf.spew.implementation.streams.udp.base;
import cf.spew.implementation.streams.base;
import cf.spew.streams.udp;

abstract class AnUDPLocalPoint : StreamPoint, ISocket_UDPLocalPoint {
}

abstract class AnUDPEndPoint : StreamPoint, ISocket_UDPEndPoint {
}
