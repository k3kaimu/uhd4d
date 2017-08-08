module uhd.usrp;

import core.stdc.time;

import std.datetime;
import uhd.utils;
import uhd.capi;
import std.typecons;


struct TxMetaData
{
    this(uhd_tx_metadata_handle handle)
    {
        _handle = handle;

        uhd_tx_metadata_has_time_spec(_handle, &_hasTimeSpec).checkUHDError();

        if(_hasTimeSpec){
            time_t fullSecs;
            double fracSecs;

            uhd_tx_metadata_time_spec(_handle, &fullSecs, &fracSecs).checkUHDError();
        }

        uhd_tx_metadata_start_of_burst(_handle, &_startOfBurst).checkUHDError();
        uhd_tx_metadata_end_of_burst(_handle, &_endOfBurst).checkUHDError();
    }


    this(SysTime time, bool startOfBurst, bool endOfBurst)
    {
        auto uxtime = time.splitToUnixTime();

        this(true, uxtime[0], uxtime[1], startOfBurst, endOfBurst);
    }


    this(bool hasTimeSpec, time_t fullSecs, double fracSecs, bool startOfBurst, bool endOfBurst)
    {
        _hasTimeSpec = hasTimeSpec;
        _time = toSysTime(fullSecs, fracSecs);
        _startOfBurst = startOfBurst;
        _endOfBurst = endOfBurst;

        uhd_tx_metadata_make(&_handle, _hasTimeSpec, fullSecs, fracSecs, _startOfBurst, _endOfBurst).checkUHDError();
    }


    @disable
    this(this);


    ~this()
    {
        if(_handle !is null) uhd_tx_metadata_free(&_handle);
    }


    uhd_tx_metadata_handle handle() @property
    {
        return _handle;
    }


  private:
    uhd_tx_metadata_handle _handle;
    bool _hasTimeSpec;
    SysTime _time;
    bool _startOfBurst;
    bool _endOfBurst;
}


struct RxMetaData
{
    this(uhd_rx_metadata_handle handle)
    {
        _handle = handle;
    }


    ~this()
    {
        uhd_rx_metadata_free(&_handle);
    }


    @disable
    this(this);


    bool hasTimeSpec() @property
    {
        bool b;
        uhd_rx_metadata_has_time_spec(_handle, &b);
        return b;
    }


    uhd_rx_metadata_error_code_t errorCode() @property
    {
        uhd_rx_metadata_error_code_t res;
        uhd_rx_metadata_error_code(_handle, &res);
        return res;
    }


  private:
    uhd_rx_metadata_handle _handle;
}


RxMetaData makeRxMetaData()
{
    uhd_rx_metadata_handle handle;
    uhd_rx_metadata_make(&handle);
    return RxMetaData(handle);
}


struct MultiDeviceAddress
{
    this(size_t N)(string[N] addrs...)
    {
        _addrs = addrs[].dup;
    }


    void pushBack(string addr)
    {
        _addrs ~= addr;
    }


    string[] address() @property { return _addrs; }


    string toUHDString()
    {
        import std.array : appender;
        import std.format : formattedWrite;

        auto app = appender!string();

        foreach(i, e; _addrs)
            app.formattedWrite("addr%s = %s\n", i, e);

        return app.data;
    }


  private:
    string[] _addrs;
}


struct TuneRequest
{
    this(double targetFreq)
    {
        _value.target_freq = targetFreq;
        _value.rf_freq_policy = uhd_tune_request_policy_t.AUTO;
        _value.dsp_freq_policy = uhd_tune_request_policy_t.AUTO;
    }

  private:
    uhd_tune_request_t _value;
}


struct TuneResult
{
  @property const
  {
    double clippedRFFreq() const { return _value.clipped_rf_freq; }
    double targetRFFreq() const { return _value.target_rf_freq; }
    double actualRFFreq() const { return _value.actual_rf_freq; }
    double targetDSPFreq() const { return _value.target_dsp_freq; }
    double actualDSPFreq() const { return _value.actual_dsp_freq; }
  }

  private:
    uhd_tune_result_t _value;
}


struct StreamArgs
{
    this(string cpuFormat, string otwFormat, string args, in size_t[] chlist = [1])
    {
        import std.string : toStringz;
        _cvalue.cpu_format = cast(char*)cpuFormat.dup.toStringz();
        _cvalue.otw_format = cast(char*)otwFormat.dup.toStringz();
        _cvalue.args = cast(char*)args.dup.toStringz();
        _cvalue.channel_list = chlist.dup.ptr;
        _cvalue.n_channels = cast(int)chlist.length;
    }


    ref uhd_stream_args_t toCValue()
    {
        return _cvalue;
    }


  private:
    uhd_stream_args_t _cvalue;
}


struct StreamCommand
{
    static
    StreamCommand startContinuous()
    {
        StreamCommand cmd;
        with(cmd._value){
            stream_mode = uhd_stream_mode_t.START_CONTINUOUS;
            num_samps = 0;
            stream_now = true;
            time_spec_full_secs = 0;
            time_spec_frac_secs = 0;
        }

        return cmd;
    }


    static
    StreamCommand stopContinuous()
    {
        StreamCommand cmd;
        with(cmd._value){
            stream_mode = uhd_stream_mode_t.STOP_CONTINUOUS;
            num_samps = 0;
            stream_now = false;
            time_spec_full_secs = 0;
            time_spec_frac_secs = 0;
        }

        return cmd;
    }

  private:
    uhd_stream_cmd_t _value;
}


struct RxStreamer
{
    this(ref USRPHandle usrpHandle, ref StreamArgs args)
    {
        uhd_rx_streamer_make(&(_handle)).checkUHDError();
        uhd_usrp_get_rx_stream(usrpHandle._handle, &(args.toCValue()), _handle).checkUHDError();
    }


    @disable this(this);


    ~this()
    {
        if(_handle !is null)
            uhd_rx_streamer_free(&_handle);
    }


    size_t maxNumSamps() @property
    {
        size_t res;
        uhd_rx_streamer_max_num_samps(_handle, &res).checkUHDError();
        return res;
    }


    size_t recv(T)(T[] buffer, ref RxMetaData md, double timeout)
    {
        size_t res;
        void* p = cast(void*)buffer.ptr;
        uhd_rx_streamer_recv(_handle, &p, buffer.length, &(md._handle), timeout, false, &res).checkUHDError();
        return res;
    }


    void issue(StreamCommand cmd)
    {
        uhd_rx_streamer_issue_stream_cmd(_handle, &(cmd._value)).checkUHDError();
    }


  private:
    //USRPHandle _usrpHandle;
    uhd_rx_streamer_handle _handle;
}


struct TxStreamer
{
    this(ref USRPHandle usrpHandle, StreamArgs args)
    {
        uhd_tx_streamer_make(&(_handle)).checkUHDError();
        uhd_usrp_get_tx_stream(usrpHandle._handle, &(args.toCValue()), _handle).checkUHDError();
    }


    @disable this(this);


    ~this()
    {
        if(_handle !is null)
            uhd_tx_streamer_free(&_handle);
    }


    size_t maxNumSamps() @property
    {
        size_t res;
        uhd_tx_streamer_max_num_samps(_handle, &res).checkUHDError();
        return res;
    }


    size_t send(T)(in T[] buffer, ref TxMetaData metadata, double timeout)
    {
        size_t res;
        void* p = cast(void*)buffer.ptr;
        uhd_tx_streamer_send(_handle, &p, buffer.length, &(metadata._handle), timeout, &res).checkUHDError();

        return res;
    }


  private:
    //USRPHandle _usrpHandle;
    uhd_tx_streamer_handle _handle;
}


//private
struct USRPHandle
{
    this(string args)
    {
        import std.string : toStringz;

        const char* cargs = args.toStringz();
        auto error = uhd_usrp_make(&_handle, cargs);
        checkUHDError(error);
    }


    this(MultiDeviceAddress addr)
    {
        this(addr.toUHDString());
    }


    @disable this(this);


    ~this()
    {
        if(_handle !is null)
            uhd_usrp_free(&_handle);
    }


  private:
    uhd_usrp_handle _handle;
}


struct USRP
{
    this(string args)
    {
        _handle = USRPHandle(args);
    }


    this(MultiDeviceAddress addr)
    {
        _handle = USRPHandle(addr);
    }


    @disable this(this);


    void txRate(double rate) @property
    {
        uhd_usrp_set_tx_rate(_handle._handle, rate, 0).checkUHDError();
    }


    double txRate() @property
    {
        double rate;
        uhd_usrp_get_tx_rate(_handle._handle, 0, &rate).checkUHDError();
        return rate;
    }


    void rxRate(double rate) @property
    {
        uhd_usrp_set_rx_rate(_handle._handle, rate, 0).checkUHDError();
    }


    double rxRate() @property
    {
        double rate;
        uhd_usrp_get_rx_rate(_handle._handle, 0, &rate).checkUHDError();
        return rate;
    }


    void txGain(double gain) @property
    {
        uhd_usrp_set_tx_gain(_handle._handle, gain, 0, "").checkUHDError();
    }


    double txGain() @property
    {
        double gain;
        uhd_usrp_get_tx_gain(_handle._handle, 0, "", &gain).checkUHDError();
        return gain;
    }


    void rxGain(double gain) @property
    {
        uhd_usrp_set_rx_gain(_handle._handle, gain, 0, "").checkUHDError();
    }


    double rxGain() @property
    {
        double gain;
        uhd_usrp_get_rx_gain(_handle._handle, 0, "", &gain).checkUHDError();
        return gain;
    }


    TuneResult txFreq(double freq) @property
    {
        auto req = TuneRequest(freq);
        TuneResult res;
        uhd_usrp_set_tx_freq(_handle._handle, &(req._value), 0, &(res._value)).checkUHDError();
        return res;
    }


    double txFreq() @property
    {
        double freq;
        uhd_usrp_get_tx_freq(_handle._handle, 0, &freq).checkUHDError();
        return freq;
    }


    TuneResult rxFreq(double freq) @property
    {
        auto req = TuneRequest(freq);
        TuneResult res;
        uhd_usrp_set_rx_freq(_handle._handle, &(req._value), 0, &(res._value)).checkUHDError();
        return res;
    }


    double rxFreq() @property
    {
        double freq;
        uhd_usrp_get_rx_freq(_handle._handle, 0, &freq).checkUHDError();
        return freq;
    }


    void clockSource(string source) @property
    {
        import std.string : toStringz;
        uhd_usrp_set_clock_source(_handle._handle, source.toStringz(), 0).checkUHDError();
    }


    string clockSource() @property
    {
        import std.conv : to;

        char[32] buffer;
        uhd_usrp_get_clock_source(_handle._handle, 0, buffer.ptr, 32);
        return buffer.ptr.to!string;
    }


    void timeSource(string source) @property
    {
        import std.string : toStringz;

        uhd_usrp_set_time_source(_handle._handle, source.toStringz(), 0).checkUHDError();
    }


    string timeSource() @property
    {
        import std.conv : to;

        char[32] buffer;
        uhd_usrp_get_time_source(_handle._handle, 0, buffer.ptr, 16);
        return buffer.ptr.to!string;
    }


    RxStreamer makeRxStreamer(StreamArgs args)
    {
        return RxStreamer(_handle, args);
    }


    TxStreamer makeTxStreamer(StreamArgs args)
    {
        return TxStreamer(_handle, args);
    }

  private:
    USRPHandle _handle;
}
