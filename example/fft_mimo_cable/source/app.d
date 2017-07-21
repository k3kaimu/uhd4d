
import std.stdio;
import std.concurrency;
import std.complex;
import std.datetime;
import core.thread;
import std.traits;

import carbon.channel;
import carbon.math;
import fdphy.blas;

import uhd.usrp;

enum real sampFreq = 1e6;
enum real centerFreq = 5.11e9;

void newThreadExceptionHandler(alias func)(ParameterTypeTuple!func params)
{
    try
        func(params);
    catch(Exception ex) writeln(ex);
    catch(Error err) writeln(err);
}


real fftAndGetPeak(shared Channel!(immutable(Complex!float)[]) ch, shared Channel!bool term)
{
    immutable fftSize = (cast(size_t)sampFreq).nextPowOf2;
    immutable(Complex!float)[] samps;

    while(samps.length < fftSize){
        if(auto p = ch.pop!(immutable(Complex!float)[])){
            samps ~= *p;
            continue;
        }else
            Thread.sleep(1.msecs);
    }

    term.put(true);

    import std.numeric : fft;
    auto fftres = fft(samps[0 .. fftSize]);
    long maxi = BLAS.ixamax(fftres);

    if(maxi > fftSize/2)
        maxi -= fftSize;

    writeln(maxi);

    return sampFreq / fftSize * maxi;
}


void dropAllData(T)(shared Channel!T ch)
{
    while(1){
        if(auto p = ch.pop!T) continue;
        break;
    }
}


void main()
{
    auto txTerm = channel!bool();
    auto rxTerm = channel!bool();
    auto rxData = channel!(immutable(Complex!float)[]);

    spawn(&newThreadExceptionHandler!txThread, "192.168.10.18", "internal", txTerm);
    spawn(&newThreadExceptionHandler!rxThread, "192.168.10.17", centerFreq, "internal", rxData, rxTerm);

    // read from rx
    immutable freqDiff1 = fftAndGetPeak(rxData, rxTerm);
    writefln("Center Frequency Error(Internal, Internal): %s [Hz]", freqDiff1);

    //// drop all rx data
    //rxData.dropAllData();

    //// spawn new rx thread
    //spawn(&newThreadExceptionHandler!rxThread, "192.168.10.12", centerFreq + freqDiff1, "internal", rxData, rxTerm);

    //immutable freqDiff2 = fftAndGetPeak(rxData, rxTerm);
    //writefln("Center Frequency Error(Internal, Internal + %s[Hz]): %s [Hz]", freqDiff1, freqDiff2);

    //// drop all rx data
    //rxData.dropAllData();

    //// spawn new rx thread
    //spawn(&newThreadExceptionHandler!rxThread, "192.168.10.12", centerFreq, "mimo", rxData, rxTerm);

    //immutable freqDiff3 = fftAndGetPeak(rxData, rxTerm);
    //writefln("Center Frequency Error(Internal, MIMO): %s [Hz]", freqDiff3);
}



void txThread(string addr, string clock_time_source, shared Channel!bool terminate)
{
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

    auto buffer = new Complex!float[maxlen];
    foreach(i, ref e; buffer){
        e.re = 0.3;
        e.im = 0;
    }

    auto md = TxMetaData(false, 0, 0.1, true, false);

    while(1)
    {
        StopWatch sw;
        sw.start();
        foreach(i; 0 .. 1024){
            auto nsend = txStreamer.send(buffer, md, 0.1);
            assert(nsend == maxlen);
        }
        sw.stop();
        writefln("Sent: %e [Msps]", 1024.0 * maxlen * 1E6 / sw.peek.usecs);

        if(auto p = terminate.pop!bool){
            writeln("END: TX Thread");
            break;
        }
    }
}


void rxThread(string addr, double freq, string clock_time_source, shared Channel!(immutable(Complex!float)[]) ch, shared Channel!bool terminate)
{
    auto usrp = USRP(MultiDeviceAddress([addr]));

    usrp.rxRate = sampFreq;
    writeln("Actual RX Rate: ", usrp.rxRate);

    usrp.rxGain = 15;
    writeln("Actual RX Gain: ", usrp.rxGain);

    usrp.rxFreq = freq;
    writefln("Actual RX freq: %s [MHz]", usrp.rxFreq / 1e6);

    usrp.clockSource = clock_time_source;
    writefln("Actual clock source: %s", usrp.clockSource);

    if(clock_time_source == "mimo")
        usrp.timeSource = clock_time_source;

    writefln("Actual time source: %s", usrp.timeSource);

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
