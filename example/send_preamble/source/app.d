
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
import fdphy.spec;
import fdphy.pkt.preamble;
import fdphy.pkt.est;
import fdphy.pkt.data;
import fdphy.fd.learning;

enum real sampFreq = 4e6;
enum real centerFreq = 5.11e9;
enum size_t numOfInterval = 1024;


void main()
{
    auto txTerm = channel!bool();
    auto rxTerm = channel!bool();
    auto acqTerm = channel!bool();
    auto txData = channel!(immutable(Complex!float)[]);
    auto rxData = channel!(immutable(Complex!float)[]);

    spawn(&newThreadExceptionHandler!txThread, "192.168.10.18", "internal", txData, txTerm);
    spawn(&newThreadExceptionHandler!rxThread, "192.168.10.17", "mimo", rxData, rxTerm);

    spawn(&newThreadExceptionHandler!acqThread, rxData, acqTerm);

    //auto sincos1 = new Complex!float[numOfInterval];
    //foreach(i, ref e; sincos1)
    //    e = std.complex.expi(- 1.0L * i / numOfInterval * 2 * PI);

    //auto sincos = cycle(sincos1);

    //while(1){
    //    if(auto p = rxData.pop!(immutable(Complex!float)[])){
    //        auto signal = *p;
            
    //        Complex!float sum = complex!float(0, 0);
    //        foreach(i; 0 .. signal.length){
    //            sum += signal[i] * sincos.front;
    //            sincos.popFront();
    //        }

    //        writefln("sum: %f", atan2(sum.im, sum.re) / PI * 180);
    //    }
    //}

    auto preambles = Preambles(false);

    foreach(line; stdin.byLine){
        writeln("SEND");
        if(line.startsWith("q"))
            break;
        else
            txData.put(preambles.myEST);
    }

    txTerm.put(true);
    rxTerm.put(true);
    acqTerm.put(true);
}


void newThreadExceptionHandler(alias func)(ParameterTypeTuple!func params)
{
    try
        func(params);
    catch(Exception ex) writeln(ex);
    catch(Error err) writeln(err);
}


void acqThread(shared Channel!(immutable(Complex!float)[]) ch, shared Channel!bool terminate)
{
    enum size_t numOfChunkCheckHeader = Constant.nOverSampling * 1024;
    import std.container : DList;

    auto preambles = Preambles(false);

    size_t receiveQueueLen;
    DList!(immutable(Complex!float)[]) receiveQueue;

    void pushToReceiveQueue(immutable(Complex!float)[] buf)
    {
        receiveQueue ~= buf;
        receiveQueueLen += buf.length;
//        writeln(receiveQueueLen);
/*
        size_t num;
        foreach(e; receiveQueue[])
            num += e.length;

        assert(num == receiveQueueLen);*/
    }


    void dropReceiveQueue(size_t num)
    {
        if(receiveQueueLen <= num){
            while(!receiveQueue.empty) receiveQueue.removeFront();
            receiveQueueLen = 0;
            return;
        }

        receiveQueueLen -= num;

        size_t remain = num;
        while(remain != 0){
            auto fb = receiveQueue.front;
            auto rmlen = min(fb.length, remain);
            remain -= rmlen;

            if(rmlen == fb.length)
                receiveQueue.removeFront();
            else
                receiveQueue.front = fb[rmlen .. $];
        }
    }


    void arrangeReceiveQueue()
    {
        if(receiveQueueLen < numOfChunkCheckHeader * 2) return;
        if(receiveQueue.front.length < numOfChunkCheckHeader * 2)
        {
            Complex!float[] buffer = new Complex!float[numOfChunkCheckHeader * 2];
            Complex!float[] remain = buffer;
            while(remain.length)
            {
                auto fb = receiveQueue.front;
                auto rlen = remain.length;
                auto slen = fb.length;
                auto clen = min(rlen, slen);

                remain[0 .. clen] = fb[0 .. clen];
                remain = remain[clen .. $];

                if(clen == slen)
                    receiveQueue.removeFront();
                else
                    receiveQueue.front = fb[clen .. $];
            }

            receiveQueue.insertFront(cast(immutable)buffer);
        }
    }


    size_t detectedIndex;
    PreambleDetector detector = new PreambleDetector(preambles);
    bool checkPreamble(string tgt)()
    {
        if(receiveQueueLen < numOfChunkCheckHeader * 2) return false;
        arrangeReceiveQueue();
//	writeln(receiveQueue.front.length);

        auto res = detector.detect!tgt(receiveQueue.front);
        if(res[0]){
            detectedIndex = res[1];
            return true;
        }else
            return false;
    }


    while(1){
        if(auto p = ch.pop!(immutable(Complex!float)[])){
            pushToReceiveQueue(*p);

            if(checkPreamble!"MyEST"()){
               // dropReceiveQueue(preambles.myEST.length);
                writeln("Receive EST");
            }
            if(receiveQueueLen > 2*1024*4)
                dropReceiveQueue(preambles.myEST.length);
        }


        if(auto p = terminate.pop!bool){
            writeln("END: TX Thread");
            break;
        }
    }
}



void txThread(string addr, string clock_time_source, shared Channel!(immutable(Complex!float)[]) ch, shared Channel!bool terminate)
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

    immutable(Complex!float)[] zeros;
    {
        auto dst = new Complex!float[maxlen];
        foreach(i, ref e; dst)
            e = Complex!float(0, 0);

        zeros = cast(immutable)dst;
    }

    auto md = TxMetaData(false, 0, 0.1, true, false);

    while(1)
    {
        immutable(Complex!float)[] remain;

        if(auto p = ch.pop!(immutable(Complex!float)[]))
            remain = *p;
        else
            remain = zeros;

        while(remain.length){
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
        auto buffer = new Complex!float[maxlen];

        //StopWatch sw;
        //sw.start();
        foreach(i; 0 .. 1){
            auto nsend = rxStreamer.recv(buffer[i*maxlen .. (i+1)*maxlen], md, 0.1);
            assert(nsend == maxlen);
        }
        //sw.stop();
        //writefln("Recv: %e [Msps]", 1024.0 * maxlen * 1E6 / sw.peek.usecs);

        ch.put(cast(immutable)buffer);

        if(auto p = terminate.pop!bool){
            writeln("END: RX Thread");
            break;
        }
    }
}
