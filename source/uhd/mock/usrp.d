module uhd.mock.usrp;


import uhd.usrp;
import std.range;
import std.complex;


struct USRPMock
{
    this(string args) {}


    this(MultiDeviceAddress addr) {}


    @disable this(this);


    double txRate;
    double rxRate;
    double txGain;
    double rxGain;
    double txFreq;
    double rxFreq;
    string clockSource;
    string timeSource;


    RxStreamerMock makeRxStreamer(StreamArgs args)
    {
        return RxStreamerMock.init;
    }


    TxStreamerMock makeTxStreamer(StreamArgs args)
    {
        return TxStreamerMock.init;
    }


    static
    InputRange!(Complex!float) receivedSignal;
}

struct RxStreamerMock
{
    @disable this(this);


    size_t maxNumSamps() @property
    {
        return 312;
    }


    size_t recv(T)(T[] buffer, ref RxMetaData md, double timeout)
    {
        auto buf = buffer[0 .. this.maxNumSamps];
        foreach(ref e; buf){
            if(USRPMock.receivedSignal is null || USRPMock.receivedSignal.empty){
                e = Complex!float(uniform01() * 0.001, uniform01() * 0.001);
            }else{
                e = USRPMock.receivedSignal.front;
                USRPMock.receivedSignal.popFront();
            }
        }

        return this.maxNumSamps;
    }


    void issue(StreamCommand cmd)
    {
        //uhd_rx_streamer_issue_stream_cmd(_handle, &(cmd._value)).checkUHDError();
    }
}

struct TxStreamerMock
{
    @disable this(this);


    size_t maxNumSamps() @property
    {
        return 1024;
    }


    size_t send(T)(in T[] buffer, ref TxMetaData metadata, double timeout)
    {
        return 1024;
    }
}

unittest
{

}
