//
// Copyright 2010-2012,2014-2015 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import std.complex;
import std.math;
import std.stdio;
import std.path;
import std.format;
import std.string;
import std.getopt;
import std.range;
import std.algorithm;
import std.conv;
import std.exception;
import std.meta;
import uhd.usrp;
import uhd.capi;
import uhd.utils;
import core.time;
import core.thread;


/***********************************************************************
 * Signal handlers
 **********************************************************************/
shared bool stop_signal_called = false;
extern(C) void sig_int_handler(int) nothrow @nogc @system
{
    stop_signal_called = true;
}

/***********************************************************************
 * Utilities
 **********************************************************************/
//! Change to filename, e.g. from usrp_samples.dat to usrp_samples.00.dat,
//  but only if multiple names are to be generated.
string generate_out_filename(string base_fn, size_t n_names, size_t this_name)
{
    if (n_names == 1) {
        return base_fn;
    }

    return base_fn.setExtension(format("%02d.%s", base_fn.extension));
}


/***********************************************************************
 * transmit_worker function
 * A function to be used as a boost::thread_group thread for transmitting
 **********************************************************************/
void transmit_worker(
    size_t samplesPerBuffer,
    immutable(Complex!float[])[] wave_table,
    ref TxStreamer tx_streamer,
    ref TxMetaData metadata,
    size_t num_channels
){
    Complex!float[][] buffs = new Complex!float[][](num_channels, samplesPerBuffer);
    size_t[] indexList = new size_t[num_channels];
    TxMetaData afterFirstMD = TxMetaData(false, 0, 0, false, false);
    TxMetaData endMD = TxMetaData(false, 0, 0, false, true);
    TxMetaData* mdp = &metadata;
    VUHDException error;

    //send data until the signal handler gets called
    () @nogc {
        while(!stop_signal_called){
            //fill the buffer with the waveform
            foreach(ch; 0 .. num_channels){
                foreach(n; 0 .. samplesPerBuffer){
                    indexList[ch] += 1;
                    buffs[ch][n] = wave_table[ch][indexList[ch] % $];
                }
            }

            //send the entire contents of the buffer
            size_t txsize;
            if(auto err =tx_streamer.send(buffs, *mdp, 0.1, txsize)){
                error = err;
                return;
            }

            if(mdp !is &afterFirstMD)
                mdp = &afterFirstMD;
        }
    }();

    //send a mini EOB packet
    foreach(ref e; buffs) e.length = 0;
    tx_streamer.send(buffs, endMD, 0.1);

    if(error)
        throw error.makeException();
}


/***********************************************************************
 * recv_to_file function
 **********************************************************************/
void recv_to_file(E)(
    ref USRP usrp,
    string cpu_format,
    string wire_format,
    string file,
    size_t samps_per_buff,
    size_t num_requested_samples,
    float settling_time,
    immutable(size_t)[] rx_channel_nums
){
    int num_total_samps = 0;
    //create a receive streamer
    StreamArgs stream_args = StreamArgs(cpu_format, wire_format, "", rx_channel_nums);
    RxStreamer rx_stream = usrp.makeRxStreamer(stream_args);

    // Prepare buffers for received samples and metadata
    RxMetaData md;
    E[][] buffs = new E[][](rx_channel_nums.length, samps_per_buff);

    //create a vector of pointers to point to each of the channel buffers
    E*[] buff_ptrs;
    for (size_t i = 0; i < buffs.length; i++)
        buff_ptrs ~= buffs[i].ptr;

    // Create one ofstream object per channel
    import core.stdc.stdio : FILE, fwrite, fopen, fclose;
    FILE*[] outfiles;
    scope(exit){
        foreach(ref f; outfiles){
            fclose(f);
            f = null;
        }
    }
    for (size_t i = 0; i < buffs.length; i++) {
        string this_filename = generate_out_filename(file, buffs.length, i);
        FILE* fp = fopen(this_filename.toStringz, "wb");
        if(fp is null) throw new Exception("Cannot open file: " ~ this_filename);
        outfiles ~= fp;
    }
    enforce(outfiles.length == buffs.length);
    enforce(buffs.length == rx_channel_nums.length);
    bool overflow_message = true;
    float timeout = settling_time + 0.1f; //expected settling time + padding for first recv

    //setup streaming
    StreamCommand stream_cmd = num_requested_samples == 0 ?
        StreamCommand.startContinuous :
        StreamCommand.numSampsAndDone(num_requested_samples);

    stream_cmd.streamNow = false;
    stream_cmd.timeSpec = (cast(long)floor(settling_time*1E6)).usecs;
    rx_stream.issue(stream_cmd);

    VUHDException error;
    () @nogc {
        while(! stop_signal_called && (num_requested_samples > num_total_samps || num_requested_samples == 0)){
            // size_t num_rx_samps = rx_stream.recv(buff_ptrs, samps_per_buff, md, timeout);
            size_t num_rx_samps;
            if(auto err = rx_stream.recv(buffs, md, timeout, num_rx_samps)){
                error = err;
                return;
            }
            timeout = 0.1f; //small timeout for subsequent recv

            md.ErrorCode errorCode;
            if(auto uhderr = md.getErrorCode(errorCode)){
                error = uhderr;
                return;
            }
            if (errorCode == md.ErrorCode.TIMEOUT) {
                import core.stdc.stdio : puts;
                puts("Timeout while streaming");
                break;
            }
            if (errorCode == md.ErrorCode.OVERFLOW) {
                if (overflow_message){
                    import core.stdc.stdio : fprintf, stderr;
                    overflow_message = false;
                    fprintf(stderr, "Got an overflow indication.");
                }
                continue;
            }
            if (errorCode != md.ErrorCode.NONE){
                import core.stdc.stdio : fprintf, stderr;
                md.printError();
                fprintf(stderr, "Unknown error.");
            }

            num_total_samps += num_rx_samps;

            foreach(i, ref f; outfiles){
                fwrite(buffs[i].ptr, E.sizeof, buffs[i].length, f);
            }
        }
    }();

    // Shut down receiver
    rx_stream.issue(StreamCommand.stopContinuous);

    if(error)
        throw error.makeException();
}


/***********************************************************************
 * Main function
 **********************************************************************/
void main(string[] args){
    uhd_set_thread_priority(uhd_default_thread_priority, true);

    //transmit variables to be set by po
    string[] txfiles;
    string tx_args, /*wave_type,*/ tx_ant, tx_subdev, ref_, otw, tx_channels;
    double tx_rate, tx_freq, tx_gain, /*wave_freq,*/ tx_bw;
    float ampl;

    //receive variables to be set by po
    string rx_args, file, type, rx_ant, rx_subdev, rx_channels;
    size_t total_num_samps, spb;
    double rx_rate, rx_freq, rx_gain, rx_bw;
    float settling;
    bool tx_int_n, rx_int_n;

    // set default values
    file = "usrp_samples.dat";
    type = "short";
    ampl = 0.3;
    settling = 0.2;
    // wave_freq = 0;

    auto helpInformation = getopt(
        args,
        "tx-args",  "uhd transmit device address args",             &tx_args,
        "rx-args",  "uhd receive device address args",              &rx_args,
        "file",     "name of the file to write binary samples to",  &file,
        "type",     "sample type in file: double, float, or short", &type,
        "nsamps",   "total number of samples to receive",           &total_num_samps,
        "settling", "total time (seconds) before receiving",        &settling,
        "spb",      "samples per buffer, 0 for default",            &spb,
        "tx-rate",  "rate of transmit outgoing samples",            &tx_rate,
        "rx-rate",  "rate of receive incoming samples",             &rx_rate,
        "tx-freq",  "transmit RF center frequency in Hz",           &tx_freq,
        "rx-freq",  "receive RF center frequency in Hz",            &rx_freq,
        "ampl",     "amplitude of the waveform [0 to 0.7]",         &ampl,
        "tx-gain",  "gain for the transmit RF chain",               &tx_gain,
        "rx-gain",  "gain for the receive RF chain",                &rx_gain,
        "tx-ant",   "transmit antenna selection",                   &tx_ant,
        "rx-and",   "receive antenna selection",                    &rx_ant,
        "tx-subdev",    "transmit subdevice specification",         &tx_subdev,
        "rx-subdev",    "receive subdevice specification",          &rx_subdev,
        "tx-bw",    "analog transmit filter bandwidth in Hz",       &tx_bw,
        "rx-bw",    "analog receive filter bandwidth in Hz",        &rx_bw,
        "txfiles",  "transmit waveform file",                       &txfiles, 
        // "wave-type",    "waveform type (CONST, SQUARE, RAMP, SINE)",    &wave_type,
        // "wave-freq",    "waveform frequency in Hz",                 &wave_freq,
        "ref",      "clock reference (internal, external, mimo)",   &ref_,
        "otw",      "specify the over-the-wire sample mode",        &otw,
        "tx-channels",  `which TX channel(s) to use (specify "0", "1", "0,1", etc)`,    &tx_channels,
        "rx-channels",  `which RX channel(s) to use (specify "0", "1", "0,1", etc)`,    &rx_channels,
        "tx_int_n", "tune USRP TX with integer-N tuing", &tx_int_n,
        "rx_int_n", "tune USRP RX with integer-N tuing", &rx_int_n,
    );

    if(helpInformation.helpWanted){
        defaultGetoptPrinter("UHD TXRX Loopback to File.", helpInformation.options);
        return;
    }

    writefln("Creating the transmit usrp device with: %s...", tx_args);
    USRP tx_usrp = USRP(tx_args);
    writefln("Creating the receive usrp device with: %s...", rx_args);
    USRP rx_usrp = USRP(rx_args);

    //detect which channels to use
    // std::vector<std::string> tx_channel_strings;
    // std::vector<size_t> tx_channel_nums;
    // boost::split(tx_channel_strings, tx_channels, boost::is_any_of("\"',"));
    // for(size_t ch = 0; ch < tx_channel_strings.size(); ch++){
    //     size_t chan = boost::lexical_cast<int>(tx_channel_strings[ch]);
    //     if(chan >= tx_usrp->get_tx_num_channels()){
    //         throw std::runtime_error("Invalid TX channel(s) specified.");
    //     }
    //     else tx_channel_nums.push_back(boost::lexical_cast<int>(tx_channel_strings[ch]));
    // }
    immutable(size_t)[] tx_channel_nums = tx_channels.splitter(',').map!(to!size_t).array();
    enforce(tx_channel_nums.length == txfiles.length, "The number of channels is not equal to the number of txfiles.");
    foreach(e; tx_channel_nums) enforce(e < tx_usrp.txNumChannels, "Invalid TX channel(s) specified.");

    immutable(size_t)[] rx_channel_nums = rx_channels.splitter(',').map!(to!size_t).array();
    foreach(e; rx_channel_nums) enforce(e < rx_usrp.rxNumChannels, "Invalid RX channel(s) specified.");

    //Lock mboard clocks
    tx_usrp.clockSource = ref_;
    rx_usrp.clockSource = ref_;

    //always select the subdevice first, the channel mapping affects the other settings
    // if (vm.count("tx-subdev")) tx_usrp->set_tx_subdev_spec(tx_subdev);
    // if (vm.count("rx-subdev")) rx_usrp->set_rx_subdev_spec(rx_subdev);
    if(! tx_subdev.empty) tx_usrp.txSubdevSpec = tx_subdev;
    if(! rx_subdev.empty) rx_usrp.rxSubdevSpec = rx_subdev;

    static if(0){
        writeln("Using TX Device: ", tx_usrp);
        writeln("Using RX Device: ", rx_usrp);
    }

    //set the transmit sample rate
    if (tx_rate.isNaN){
        writeln("Please specify the transmit sample rate with --tx-rate");
        return;
    }

    writefln("Setting TX Rate: %f Msps...", tx_rate/1e6);
    tx_usrp.txRate = tx_rate;
    writefln("Actual TX Rate: %f Msps...", tx_usrp.txRate/1e6);

    //set the receive sample rate
    if (rx_rate.isNaN){
        writeln("Please specify the sample rate with --rx-rate");
        return;
    }
    writefln("Setting RX Rate: %f Msps...", rx_rate/1e6);
    rx_usrp.rxRate = rx_rate;
    writefln("Actual RX Rate: %f Msps...", rx_usrp.rxRate/1e6);

    //set the transmit center frequency
    if (tx_freq.isNaN) {
        writeln("Please specify the transmit center frequency with --tx-freq");
        return;
    }

    // for(size_t ch = 0; ch < tx_channel_nums.size(); ch++) {
    foreach(channel; tx_channel_nums){
        if (tx_channel_nums.length > 1) {
            writefln("Configuring TX Channel %s", channel);
        }
        writefln("Setting TX Freq: %f MHz...", tx_freq/1e6);
        TuneRequest tx_tune_request = TuneRequest(tx_freq);
        if(tx_int_n) tx_tune_request.args = "mode_n=integer";
        tx_usrp.tuneTxFreq(tx_tune_request, channel);
        writefln("Actual TX Freq: %f MHz...", tx_usrp.getTxFreq(channel)/1e6);

        //set the rf gain
        if (! tx_gain.isNaN) {
            writefln("Setting TX Gain: %f dB...", tx_gain);
            tx_usrp.setTxGain(tx_gain, channel);
            writefln("Actual TX Gain: %f dB...", tx_usrp.getTxGain(channel));
        }

        //set the analog frontend filter bandwidth
        if (! tx_bw.isNaN){
            writefln("Setting TX Bandwidth: %f MHz...", tx_bw);
            tx_usrp.setTxBandwidth(tx_bw, channel);
            writefln("Actual TX Bandwidth: %f MHz...", tx_usrp.getTxBandwidth(channel));
        }

        //set the antenna
        if (! tx_ant.empty) tx_usrp.setTxAntenna(tx_ant, channel);
    }

    foreach(channel; rx_channel_nums){
        if (rx_channel_nums.length > 1) {
            writeln("Configuring RX Channel ", channel);
        }

        //set the receive center frequency
        if (rx_freq.isNaN){
            stderr.writeln("Please specify the center frequency with --rx-freq");
            return;
        }
        writeln("Setting RX Freq: %f MHz...", rx_freq/1e6);
        TuneRequest rx_tune_request = TuneRequest(rx_freq);
        if(rx_int_n) rx_tune_request.args = "mode_n=integer";
        rx_usrp.tuneRxFreq(rx_tune_request, channel);
        writefln("Actual RX Freq: %f MHz...", rx_usrp.getRxFreq(channel)/1e6);

        //set the receive rf gain
        if (! rx_gain.isNaN){
            writefln("Setting RX Gain: %f dB...", rx_gain);
            rx_usrp.setRxGain(rx_gain, channel);
            writefln("Actual RX Gain: %f dB...", rx_usrp.getRxGain(channel));
        }

        //set the receive analog frontend filter bandwidth
        if (! rx_bw.isNaN){
            writefln("Setting RX Bandwidth: %f MHz...", rx_bw/1e6);
            rx_usrp.setRxBandwidth(rx_bw, channel);
            writefln("Actual RX Bandwidth: %f MHz...", rx_usrp.getRxBandwidth(channel)/1e6);
        }
    }
    //set the receive antenna
    if (! rx_ant.empty) rx_usrp.rxAntenna = rx_ant;

    //create a transmit streamer
    //linearly map channels (index0 = channel0, index1 = channel1, ...)
    StreamArgs stream_args = StreamArgs("fc32", otw, "", tx_channel_nums);
    auto tx_stream = tx_usrp.makeTxStreamer(stream_args);

    //allocate a buffer which we re-use for each channel
    if (spb == 0) spb = tx_stream.maxNumSamps()*10;
    immutable size_t num_channels = tx_channel_nums.length;

    //setup the metadata flags
    TxMetaData md = TxMetaData(true, 0, 0.1, true, false);

    //Check Ref and LO Lock detect
    string[] tx_sensor_names, rx_sensor_names;
    // tx_sensor_names = tx_usrp->get_tx_sensor_names(0);
    // foreach(sensor; tx_usrp.getTxSensorNames(0)) tx_sensor_names ~= sensor.dup;
    foreach(i, ref usrp; AliasSeq!(tx_usrp, rx_usrp)){
        foreach(sname; usrp.getTxSensorNames(0)){
            if(sname == "lo_locked"){
                SensorValue lo_locked = tx_usrp.getTxSensor(sname, 0);
                static if(0) writefln("Checking %s: %s ...", i == 0 ? "TX" : "RX", lo_locked);
                enforce(cast(bool)lo_locked);
            }
        }
    }

    foreach(i, ref usrp; AliasSeq!(tx_usrp, rx_usrp)){
        foreach(sname; usrp.getMboardSensorNames(0)){
            if((ref_ == "mimo" && sname == "mimo_locked") || (ref_ == "external" && sname == "ref_locked")){
                SensorValue locked = tx_usrp.getTxSensor(sname, 0);
                static if(0) writefln("Checking %s: %s ...", i == 0 ? "TX" : "RX", locked);
                enforce(cast(bool)locked);
            }
        }
    }

    if (total_num_samps == 0){
        import core.stdc.signal;
        signal(SIGINT, &sig_int_handler);
        writeln("Press Ctrl + C to stop streaming...");
    }

    //reset usrp time to prepare for transmit/receive
    writeln("Setting device timestamp to 0...");
    tx_usrp.timeNow = 0.seconds;

    //start transmit worker thread
    // boost::thread_group transmit_thread;
    // transmit_thread.create_thread(boost::bind(&transmit_worker, buff, wave_table, tx_stream, md, step, index, num_channels));
    immutable(Complex!float[])[] waveTable;
    foreach(i, filename; txfiles){
        import std.file : read;
        waveTable ~= cast(immutable(Complex!float[]))read(filename);
    }

    auto transmit_thread = new Thread(delegate(){
        transmit_worker(spb, waveTable, tx_stream, md, num_channels);
    });
    transmit_thread.start();

    //recv to file
    if (type == "double") recv_to_file!(double[2])(rx_usrp, "fc64", otw, file, spb, total_num_samps, settling, rx_channel_nums);
    else if (type == "float") recv_to_file!(float[2])(rx_usrp, "fc32", otw, file, spb, total_num_samps, settling, rx_channel_nums);
    else if (type == "short") recv_to_file!(short[2])(rx_usrp, "sc16", otw, file, spb, total_num_samps, settling, rx_channel_nums);
    else {
        //clean up transmit worker
        stop_signal_called = true;
        throw new Exception("Unknown type: " ~ type);
    }

    //clean up transmit worker
    stop_signal_called = true;
    transmit_thread.join();

    //finished
    writeln("\nDone!\n");
}
