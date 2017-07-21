
import std.stdio;
import std.concurrency;
import std.complex;
import std.datetime;
import std.math;
import std.range;
import std.algorithm;
import core.thread;

import carbon.channel;
import carbon.math;
import std.traits;

import uhd.usrp;

enum real sampFreq = 1e6;
enum real centerFreq = 5.11e9;
enum size_t numOfInterval = 1024;


void main()
{
    auto txTerm = channel!bool();
    auto rxTerm = channel!bool();
    auto rxData = channel!(immutable(Complex!float)[]);

    spawn(&newThreadExceptionHandler!txThread, "192.168.10.18", "internal", txTerm);
    spawn(&newThreadExceptionHandler!rxThread, "192.168.10.17", "mimo", rxData, rxTerm);

    auto sincos1 = new Complex!float[numOfInterval];
    foreach(i, ref e; sincos1)
        e = std.complex.expi(- 1.0L * i / numOfInterval * 2 * PI);

    auto sincos = cycle(sincos1);

    while(1){
        if(auto p = rxData.pop!(immutable(Complex!float)[])){
            auto signal = *p;
            
            Complex!float sum = complex!float(0, 0);
            foreach(i; 0 .. signal.length){
                sum += signal[i] * sincos.front;
                sincos.popFront();
            }

            writefln("sum: %f", atan2(sum.im, sum.re) / PI * 180);
        }
    }

    //txTerm.put(true);
    //rxTerm.put(true);
}


void newThreadExceptionHandler(alias func)(ParameterTypeTuple!func params)
{
    try
        func(params);
    catch(Exception ex) writeln(ex);
    catch(Error err) writeln(err);
}



void txThread(string addr, string clock_time_source, shared Channel!bool terminate)
{
Thread.sleep(10.seconds);
    auto usrp = USRP(MultiDeviceAddress([addr]));

    usrp.txRate = sampFreq;
    writeln("Actual TX Rate: ", usrp.txRate);

    usrp.txGain = 15;
    writeln("Actual TX Gain: ", usrp.txGain);

    usrp.txFreq = centerFreq;
    writefln("Actual TX freq: %s [MHz]", usrp.txFreq / 1e6);

    usrp.clockSource = clock_time_source;
    writefln("Actual clock source: %s", usrp.clockSource);

    if(clock_time_source == "mimo")
        usrp.timeSource = clock_time_source;

    writefln("Actual time source: %s", usrp.timeSource);

    auto txStreamer = usrp.makeTxStreamer(StreamArgs("fc32", "sc16", "", [0]));
    auto maxlen = txStreamer.maxNumSamps;
    writefln("Buffer size in samples: %s", maxlen);

    auto buffer = new Complex!float[numOfInterval];
    foreach(i, ref e; buffer)
        e = std.complex.expi(1.0L * i / numOfInterval * 2 * PI);

    auto md = TxMetaData(false, 0, 0.1, true, false);

    while(1)
    {
//        writeln("SEND");

        Complex!float[] remain = buffer;
        while(remain.length){
//            writeln("SEND");
            auto nsend = txStreamer.send(remain[0 .. min($, maxlen)], md, 0.1);
            remain = remain[nsend .. $];
        }

        if(auto p = terminate.pop!bool){
            writeln("END: TX Thread");
            break;
        }
    }
}


void rxThread(string addr, string clock_time_source, shared Channel!(immutable(Complex!float)[]) ch, shared Channel!bool terminate)
{
//	Thread.sleep(10.seconds);
    auto usrp = USRP(MultiDeviceAddress([addr]));

    usrp.rxRate = sampFreq;
    writeln("Actual RX Rate: ", usrp.rxRate);

    usrp.rxGain = 15;
    writeln("Actual RX Gain: ", usrp.rxGain);

    usrp.rxFreq = centerFreq;
    writefln("Actual RX freq: %s [MHz]", usrp.rxFreq / 1e6);

    usrp.clockSource = clock_time_source;
    writefln("Actual clock source: %s", usrp.clockSource);

    if(clock_time_source == "mimo")
        usrp.timeSource = clock_time_source;

    auto rxStreamer = usrp.makeRxStreamer(StreamArgs("fc32", "sc16", "", [0]));
    auto maxlen = rxStreamer.maxNumSamps;
    writefln("Buffer size in samples: %s", maxlen);

    rxStreamer.issue(StreamCommand.continuousNow());

    auto md = makeRxMetaData();

    while(1)
    {
        auto buffer = new Complex!float[maxlen * 1024];

        StopWatch sw;
        sw.start();
        foreach(i; 0 .. 1024){
            auto nsend = rxStreamer.recv(buffer[i*maxlen .. (i+1)*maxlen], md, 0.1);
            assert(nsend == maxlen);
        }
        sw.stop();
        writefln("Recv: %e [Msps]", 1024.0 * maxlen * 1E6 / sw.peek.usecs);

        ch.put(cast(immutable)buffer);

        if(auto p = terminate.pop!bool){
            writeln("END: RX Thread");
            break;
        }
    }
}
