module cf.spew.implementation.streams.base;
import cf.spew.implementation.instance.state : streamPointsLL;
import cf.spew.streams.defs;

abstract class StreamPoint : IStreamThing {
    private StreamPoint nextLL, lastLL;

    ~this() {
        removeFromLifeLL();
    }

    @property {
        void onStreamClose(OnStreamClosedDel callback) {
            onStreamCloseDel = callback;
        }

        void onData(OnStreamDataDel callback) {
            onDataDel = callback;
        }

        void onServerConnect(OnStreamServerConnectedDel callback) {
            onStreamServerConnectedDel = callback;
        }

        void onConnect(OnStreamConnectedDel callback) {
            onStreamConnectedDel = callback;
        }
    }

    OnStreamClosedDel onStreamCloseDel;
    OnStreamDataDel onDataDel;
    OnStreamServerConnectedDel onStreamServerConnectedDel;
    OnStreamConnectedDel onStreamConnectedDel;

    void addToLifeLL() {
        nextLL = streamPointsLL;
        streamPointsLL = this;
        if (nextLL !is null)
            nextLL.lastLL = this;
    }

    void removeFromLifeLL() {
        if (lastLL !is null)
            lastLL.nextLL = nextLL;
        if (nextLL !is null)
            nextLL.lastLL = lastLL;

        nextLL = null;
        lastLL = null;
    }

    static void closeAllInstances() {
        auto point = cast(StreamPoint)streamPointsLL;

        while (point !is null) {
            point.close;
            point = point.nextLL;
        }

        streamPointsLL = null;
    }
}
