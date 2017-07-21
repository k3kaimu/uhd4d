import std.stdio;
import std.complex;
import std.algorithm;

import uhd.usrp;
import uhd.capi.types.metadata;

void main()
{
    auto addr = MultiDeviceAddress(["192.168.10.15"]);
    auto usrp = USRP(addr);

    usrp.rxRate = 1e6;
    writeln("Actual TX Rate: ", usrp.txRate);

    usrp.rxGain = 30;
    writeln("Actual TX Gain: ", usrp.txGain);

    usrp.rxFreq = 5.11e9;
    writefln("Actual TX freq: %s [MHz]", usrp.txFreq / 1e6);

    usrp.clockSource = "internal";
    writefln("Actual clock source: %s", usrp.clockSource);

    auto rxStreamer = usrp.makeRxStreamer(StreamArgs("fc32", "sc16", "", [0]));
    auto maxlen = rxStreamer.maxNumSamps;
    writefln("Buffer size in samples: %s", maxlen);

    rxStreamer.issue(StreamCommand.continuousNow());

    auto md = makeRxMetaData();

    auto buffer = new Complex!float[maxlen];

    while(1)
    {
        auto nsend = rxStreamer.recv(buffer, md, 0.1);
        writefln("Recv: %s", buffer[0 .. nsend].map!"a.re^^2+a.im^^2".sum());
        writeln(md.errorCode);
        if(md.errorCode != uhd_rx_metadata_error_code_t.UHD_RX_METADATA_ERROR_CODE_NONE)
        {
            break;
        }
    }
}
