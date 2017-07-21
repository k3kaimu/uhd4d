import std.stdio;
import std.complex;
import std.math;
import std.algorithm;
import std.datetime;
import core.memory;

import uhd.usrp;

void main()
{
    auto addr = MultiDeviceAddress(["192.168.10.18"]);
    auto usrp = USRP(addr);

    usrp.txRate = 1e6;
    writeln("Actual TX Rate: ", usrp.txRate);

    usrp.txGain = 20;
    writeln("Actual TX Gain: ", usrp.txGain);

    usrp.txFreq = 5.11e9;
    writefln("Actual TX freq: %s [MHz]", usrp.txFreq / 1e6);

    usrp.clockSource = "internal";
    writefln("Actual clock source: %s", usrp.clockSource);

    auto txStreamer = usrp.makeTxStreamer(StreamArgs("fc32", "sc16", "", [0]));
    auto maxlen = max(min(txStreamer.maxNumSamps, 1024), 1024);
    writefln("Buffer size in samples: %s", maxlen);

    auto buffer = new Complex!float[maxlen];
    foreach(i, ref e; buffer){
        e.re = 0.1*sin(2 * PI / maxlen * i);
        e.im = 0.1*cos(2 * PI / maxlen * i);
    }

    auto md = TxMetaData(false, 0, 0.1, true, false);

    auto firstTime = Clock.currTime;
    size_t cnt;
    StopWatch sw;
    while(1)
    {
        //GC.disable();
        foreach(i; 0 .. 1024){
            size_t cnt2;
            while(cnt2 < buffer.length)
                cnt2 += txStreamer.send(buffer[cnt2 .. $], md, 0.0001);
            //writefln("Sent: %s [samps]", nsend);
            cnt += cnt2;
            int[] buffer_ = new int[1024*128];
        }
        //sw.start();
        //GC.enable();
        //GC.collect();
        //GC.minimize();
        //sw.stop();
        writefln("GCStats: %s, %s, %s", GC.stats.usedSize, GC.stats.freeSize, sw.peek.usecs);
        writefln("Sent: %s [samps], %s [Msps]", cnt, cnt * 1000.0 / (Clock.currTime - firstTime).total!"msecs");
    }
}
