module uhd.usrp;

import core.stdc.time;

import std.datetime;
import uhd.utils;
import uhd.capi;
import std.typecons;
import std.traits;


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


    this(Duration time, bool startOfBurst, bool endOfBurst)
    {
        auto uhdTime = time.splitToFullAndFracSecs();

        this(true, uhdTime[0], uhdTime[1], startOfBurst, endOfBurst);
    }


    this(bool hasTimeSpec, time_t fullSecs, double fracSecs, bool startOfBurst, bool endOfBurst)
    {
        _hasTimeSpec = hasTimeSpec;
        _time = toDuration(fullSecs, fracSecs);
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
    Duration _time;
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
        uhd_rx_metadata_has_time_spec(_handle, &b).checkUHDError();
        return b;
    }


    ErrorCode errorCode() @property
    {
        uhd_rx_metadata_error_code_t res;
        uhd_rx_metadata_error_code(_handle, &res).checkUHDError();
        return cast(ErrorCode)res;
    }


    VUHDException getErrorCode(ref ErrorCode errorCode) @nogc nothrow
    {
        uhd_rx_metadata_error_code_t res;
        auto uhderror = uhd_rx_metadata_error_code(_handle, &res);
        errorCode = cast(ErrorCode)res;
        return VUHDException(uhderror);
    }


    void printError() @nogc
    {
        import core.stdc.stdio : puts;
        char[1024] strbuf;
        uhd_rx_metadata_strerror(_handle, strbuf.ptr, strbuf.length - 1);
        puts(strbuf.ptr);
    }


    enum ErrorCode
    {
        NONE = 0x0,
        TIMEOUT = 0x1,
        LATE_COMMAND = 0x2,
        BROKEN_CHAIN = 0x4,
        OVERFLOW = 0x8,
        ALIGNMENT = 0xC,
        BAD_PACKET = 0xF,
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


    void args(string s)
    {
        import std.string : toStringz;
        _value.args = cast(char*)s.dup.toStringz();
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


    static 
    StreamCommand numSampsAndDone(size_t samps)
    {
        StreamCommand cmd;
        with(cmd._value){
            stream_mode = uhd_stream_mode_t.NUM_SAMPS_AND_DONE;
            num_samps = samps;
            stream_now = false;
            time_spec_full_secs = 0;
            time_spec_frac_secs = 0;
        }

        return cmd;
    }


    void timeSpec(Duration dur) @property
    {
        _value.time_spec_full_secs = dur.total!"seconds";
        _value.time_spec_frac_secs = (dur.total!"nsecs" - dur.total!"seconds" * 1.0E9L) / 1.0E9L;
    }


    Duration timeSpec() @property 
    {
        import std.math;
        return _value.time_spec_full_secs.seconds + (cast(long)floor(_value.time_spec_frac_secs * 1.0E9)).nsecs;
    }


    bool streamNow() const @property { return _value.stream_now; }
    

    void streamNow(bool b) @property { _value.stream_now = b; }


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
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    {
        size_t res;
        void* p = cast(void*)buffer.ptr;
        uhd_rx_streamer_recv(_handle, &p, buffer.length, &(md._handle), timeout, false, &res).checkUHDError();
        return res;
    }


    size_t recv(T)(T[][] buffers, ref RxMetaData md, double timeout)
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    in{
        assert(buffers.length != 0);
        immutable len = buffers[0].length;
        foreach(buf; buffers) assert(buf.length == len);
    }
    body{
        size_t res;
        void*[64] buf;
        foreach(i, b; buffers) buf[i] = b.ptr;
        uhd_rx_streamer_recv(_handle, buf.ptr, buffers[0].length, &(md._handle), timeout, false, &res).checkUHDError();
        return res;
    }


    VUHDException recv(T)(T[] buffer, ref RxMetaData md, double timeout, ref size_t size) nothrow @nogc
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    {
        void* p = cast(void*)buffer.ptr;
        return VUHDException(uhd_rx_streamer_recv(_handle, &p, buffer.length, &(md._handle), timeout, false, &size));
    }


    VUHDException recv(T)(T[][] buffers, ref RxMetaData md, double timeout, ref size_t size) nothrow @nogc
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    in{
        assert(buffers.length != 0);
        immutable len = buffers[0].length;
        foreach(buf; buffers) assert(buf.length == len);
    }
    body{
        void*[64] buf;
        foreach(i, b; buffers) buf[i] = b.ptr;
        return VUHDException(uhd_rx_streamer_recv(_handle, buf.ptr, buffers[0].length, &(md._handle), timeout, false, &size));
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


    size_t numChannels() @property
    {
        size_t res;
        uhd_tx_streamer_num_channels(_handle, &res);
        return res;
    }


    size_t maxNumSamps() @property
    {
        size_t res;
        uhd_tx_streamer_max_num_samps(_handle, &res).checkUHDError();
        return res;
    }


    size_t send(T)(in T[] buffer, ref TxMetaData metadata, double timeout = 0.1)
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    {
        void* p = cast(void*)buffer.ptr;
        size_t dst;
        uhd_tx_streamer_send(_handle, &p, buffer.length, &(metadata._handle), timeout, &dst).checkUHDError();
        return dst;
    }


    size_t send(T)(in T[][] buffers, ref TxMetaData metadata, double timeout = 0.1)
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    in{
        assert(buffers.length != 0);
        immutable len = buffers[0].length;
        foreach(buf; buffers) assert(buf.length == len);
    }
    body{
        const(void)*[64] bufs;
        foreach(i, b; buffers) bufs[i] = b.ptr;
        size_t dst;
        uhd_tx_streamer_send(_handle, bufs.ptr, buffers[0].length, &(metadata._handle), timeout, &dst).checkUHDError();
        return dst;
    }


    void send(typeof(null), ref TxMetaData metadata, double timeout = 0.1)
    {
        void* p = null;
        size_t dst;
        uhd_tx_streamer_send(_handle, &p, 0, &(metadata._handle), timeout, &dst).checkUHDError();
    }


    VUHDException send(T)(in T[] buffer, ref TxMetaData metadata, double timeout, ref size_t size) nothrow @nogc
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    {
        const(void)* p = buffer.ptr;
        return VUHDException(uhd_tx_streamer_send(_handle, &p, buffer.length, &(metadata._handle), timeout, &size));
    }


    VUHDException send(T)(in T[][] buffers, ref TxMetaData metadata, double timeout, ref size_t size) nothrow @nogc
    if((!isArray!T || isStaticArray!T) && isAssignable!T)
    in{
        assert(buffers.length != 0);
        immutable len = buffers[0].length;
        foreach(buf; buffers) assert(buf.length == len);
    }
    body{
        const(void)*[64] bufs;
        foreach(i, b; buffers) bufs[i] = b.ptr;
        return VUHDException(uhd_tx_streamer_send(_handle, bufs.ptr, buffers[0].length, &(metadata._handle), timeout, &size));
    }


  private:
    //USRPHandle _usrpHandle;
    uhd_tx_streamer_handle _handle;
}


struct SubdevSpec
{
    this(string markup)
    {
        import std.string : toStringz;

        char* cstr = cast(char*)(markup.dup.toStringz);
        uhd_subdev_spec_make(&_handle, cstr);
    }


    @disable this(this);


    ~this()
    {
        uhd_subdev_spec_free(&_handle);
    }


  private:
    uhd_subdev_spec_handle _handle;
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
    enum size_t ALL_MBOARDS = ~cast(size_t)0;


    this(string args)
    {
        _handle = USRPHandle(args);
    }


    this(MultiDeviceAddress addr)
    {
        _handle = USRPHandle(addr);
    }


    @disable this(this);


    void txSubdevSpec(string markup) @property
    {
        auto spec = SubdevSpec(markup);
        uhd_usrp_set_tx_subdev_spec(_handle._handle, spec._handle, ALL_MBOARDS);
    }


    void rxSubdevSpec(string markup) @property
    {
        auto spec = SubdevSpec(markup);
        uhd_usrp_set_rx_subdev_spec(_handle._handle, spec._handle, ALL_MBOARDS);
    }


    size_t txNumChannels() @property
    {
        size_t res;
        uhd_usrp_get_tx_num_channels(_handle._handle, &res).checkUHDError();
        return res;
    }


    size_t rxNumChannels() @property
    {
        size_t res;
        uhd_usrp_get_rx_num_channels(_handle._handle, &res).checkUHDError();
        return res;
    }


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
        this.setTxGain(gain, 0);
    }


    void setTxGain(double gain, size_t channel = 0)
    {
        uhd_usrp_set_tx_gain(_handle._handle, gain, channel, "").checkUHDError();
    }


    double txGain() @property
    {
        return this.getTxGain(0);
    }


    double getTxGain(size_t channel = 0) @property
    {
        double gain;
        uhd_usrp_get_tx_gain(_handle._handle, channel, "", &gain).checkUHDError();
        return gain;
    }


    void rxGain(double gain) @property
    {
        this.setRxGain(gain, 0);
    }


    void setRxGain(double gain, size_t channel = 0)
    {
        uhd_usrp_set_rx_gain(_handle._handle, gain, channel, "").checkUHDError();
    }


    double rxGain() @property
    {
        return this.getRxGain(0);
    }


    double getRxGain(size_t channel = 0)
    {
        double gain;
        uhd_usrp_get_rx_gain(_handle._handle, channel, "", &gain).checkUHDError();
        return gain;
    }


    TuneResult txFreq(double freq) @property
    {
        auto req = TuneRequest(freq);
        return this.tuneTxFreq(req, 0);
    }


    TuneResult tuneTxFreq(ref TuneRequest request, size_t channel = 0)
    {
        TuneResult res;
        uhd_usrp_set_tx_freq(_handle._handle, &(request._value), channel, &(res._value)).checkUHDError();
        return res;
    }


    double txFreq() @property
    {
        return getTxFreq(0);
    }


    double getTxFreq(size_t channel) @property
    {
        double freq;
        uhd_usrp_get_tx_freq(_handle._handle, channel, &freq).checkUHDError();
        return freq;
    }


    TuneResult rxFreq(double freq) @property
    {
        auto req = TuneRequest(freq);
        return tuneRxFreq(req, 0);
    }


    TuneResult tuneRxFreq(ref TuneRequest request, size_t channel = 0)
    {
        TuneResult res;
        uhd_usrp_set_rx_freq(_handle._handle, &(request._value), channel, &(res._value)).checkUHDError();
        return res;
    }


    double rxFreq() @property
    {
        return this.getRxFreq(0);
    }


    double getRxFreq(size_t channel = 0)
    {
        double freq;
        uhd_usrp_get_rx_freq(_handle._handle, channel, &freq).checkUHDError();
        return freq;
    }


    void clockSource(string source) @property
    {
        this.setClockSource(source, ALL_MBOARDS);
    }


    void setClockSource(string source, size_t mboard = ALL_MBOARDS) @property
    {
        import std.string : toStringz;
        uhd_usrp_set_clock_source(_handle._handle, source.toStringz(), mboard).checkUHDError();
    }


    string clockSource() @property
    {
        import std.conv : to;

        char[32] buffer;
        uhd_usrp_get_clock_source(_handle._handle, 0, buffer.ptr, 32).checkUHDError();
        return buffer.ptr.to!string;
    }


    void timeSource(string source) @property
    {
        this.setTimeSource(source, ALL_MBOARDS);
    }


    void setTimeSource(string source, size_t mboard = ALL_MBOARDS) @property
    {
        import std.string : toStringz;

        uhd_usrp_set_time_source(_handle._handle, source.toStringz(), mboard).checkUHDError();
    }


    string timeSource() @property
    {
        import std.conv : to;

        char[32] buffer;
        uhd_usrp_get_time_source(_handle._handle, 0, buffer.ptr, 16).checkUHDError();
        return buffer.ptr.to!string;
    }


    void timeNow(Duration timeSpec) @property
    {
        this.setTimeNow(timeSpec, ALL_MBOARDS);
    }


    void setTimeNow(Duration timeSpec, size_t mboard = ALL_MBOARDS)
    {
        auto uhdtime = timeSpec.splitToFullAndFracSecs();
        uhd_usrp_set_time_now(_handle._handle, uhdtime[0], uhdtime[1], mboard).checkUHDError();
    }


    void setTimeUnknownPPS(Duration timeSpec)
    {
        auto uhdtime = timeSpec.splitToFullAndFracSecs();
        uhd_usrp_set_time_unknown_pps(_handle._handle, uhdtime[0], uhdtime[1]).checkUHDError();
    }


    void setTxAntenna(string antenna, size_t channel = 0)
    {
        import std.string : toStringz;
        uhd_usrp_set_tx_antenna(_handle._handle, antenna.toStringz, channel).checkUHDError();
    }


    void txAntenna(string antenna) @property
    {
        this.setTxAntenna(antenna, 0);
    }


    string getTxAntenna(size_t channel = 0)
    {
        import core.stdc.string : strlen;
        char[1024] str;
        uhd_usrp_get_tx_antenna(_handle._handle, channel, str.ptr, str.length - 1).checkUHDError();
        size_t len = strlen(str.ptr);
        return str[0 .. len].dup;
    }


    string txAntenna() @property
    {
        return this.getTxAntenna(0);
    }


    void setRxAntenna(string antenna, size_t channel = 0)
    {
        import std.string : toStringz;
        uhd_usrp_set_rx_antenna(_handle._handle, antenna.toStringz, channel).checkUHDError();
    }


    void rxAntenna(string antenna) @property
    {
        this.setRxAntenna(antenna, 0);
    }


    string getRxAntenna(size_t channel = 0)
    {
        import core.stdc.string : strlen;
        char[1024] str;
        uhd_usrp_get_rx_antenna(_handle._handle, channel, str.ptr, str.length - 1).checkUHDError();
        size_t len = strlen(str.ptr);
        return str[0 .. len].dup;
    }


    string rxAntenna() @property
    {
        return this.getRxAntenna(0);
    }


    void setTxBandwidth(double bw, size_t channel = 0)
    {
        uhd_usrp_set_tx_bandwidth(_handle._handle, bw, channel).checkUHDError();
    }


    void txBandwidth(double bw)
    {
        this.setTxBandwidth(bw, 0);
    }


    double getTxBandwidth(size_t channel = 0)
    {
        double bw;
        uhd_usrp_get_tx_bandwidth(_handle._handle, channel, &bw).checkUHDError();
        return bw;
    }


    double txBandwidth()
    {
        return this.getTxBandwidth(0);
    }


    void setRxBandwidth(double bw, size_t channel = 0)
    {
        uhd_usrp_set_rx_bandwidth(_handle._handle, bw, channel).checkUHDError();
    }


    void rxBandwidth(double bw)
    {
        this.setRxBandwidth(bw, 0);
    }


    double getRxBandwidth(size_t channel = 0)
    {
        double bw;
        uhd_usrp_get_rx_bandwidth(_handle._handle, channel, &bw).checkUHDError();
        return bw;
    }


    double rxBandwidth()
    {
        return this.getRxBandwidth(0);
    }


    RxStreamer makeRxStreamer(StreamArgs args)
    {
        return RxStreamer(_handle, args);
    }


    TxStreamer makeTxStreamer(StreamArgs args)
    {
        return TxStreamer(_handle, args);
    }


    StringList getTxSensorNames(size_t channel)
    {
        uhd_string_vector_handle slist;
        uhd_string_vector_make(&slist).checkUHDError();
        uhd_usrp_get_tx_sensor_names(_handle._handle, channel, &slist).checkUHDError();
        return StringList(slist);
    }


    StringList getRxSensorNames(size_t channel)
    {
        uhd_string_vector_handle slist;
        uhd_string_vector_make(&slist).checkUHDError();
        uhd_usrp_get_rx_sensor_names(_handle._handle, channel, &slist).checkUHDError();
        return StringList(slist);
    }


    StringList getMboardSensorNames(size_t mboard)
    {
        uhd_string_vector_handle slist;
        uhd_string_vector_make(&slist).checkUHDError();
        uhd_usrp_get_mboard_sensor_names(_handle._handle, mboard, &slist).checkUHDError();
        return StringList(slist);
    }


    SensorValue getTxSensor(const(char)[] name, size_t channel)
    {
        import std.string : toStringz;

        uhd_sensor_value_handle handle;
        uhd_sensor_value_make_from_string(&handle, "", "", "");
        uhd_usrp_get_tx_sensor(_handle._handle, name.toStringz, channel, &handle);
        return SensorValue(handle);
    }


    SensorValue getRxSensor(const(char)[] name, size_t channel)
    {
        import std.string : toStringz;

        uhd_sensor_value_handle handle;
        uhd_sensor_value_make_from_string(&handle, "", "", "");
        uhd_usrp_get_rx_sensor(_handle._handle, name.toStringz, channel, &handle);
        return SensorValue(handle);
    }


    SensorValue getMBoardSensor(const(char)[] name, size_t channel)
    {
        import std.string : toStringz;

        uhd_sensor_value_handle handle;
        uhd_usrp_get_mboard_sensor(_handle._handle, name.toStringz, channel, &handle);
        return SensorValue(handle);
    }


    void toString(scope void delegate(const(char)[]) sink)
    {
        import core.stdc.string : strlen;

        char[1024] str;
        uhd_usrp_get_pp_string(_handle._handle, str.ptr, str.length - 1).checkUHDError();
        size_t len = strlen(str.ptr);
        sink(str[0 .. len]);
    }


  private:
    USRPHandle _handle;
}


struct StringList
{
    this(uhd_string_vector_handle handle)
    {
        _handle = handle;
        _index = 0;
        uhd_string_vector_size(_handle, &_size).checkUHDError();
    }


    @disable this(this);


    ~this()
    {
        if(_handle !is null)
            uhd_string_vector_free(&_handle);

        _handle = null;
    }


    size_t length() const @property { return _size - _index; }


    int opApply(scope int delegate(char[]) dg)
    {
        return this.opApply((size_t i, char[] str){
            return dg(str);
        });
    }


    int opApply(scope int delegate(size_t, char[]) dg)
    {
        import core.stdc.string : strlen;

        int result;
        foreach(i; _index .. _size){
            char[1024] strbuf;
            uhd_string_vector_at(_handle, _index, strbuf.ptr, strbuf.length - 1).checkUHDError();
            size_t len = strlen(strbuf.ptr);
            result = dg(i - _index, strbuf[0 .. len]);
            if(result) break;
        }

        return result;
    }
    

  private:
    uhd_string_vector_handle _handle;
    size_t _index;
    size_t _size;
}


struct SensorList
{

}


struct SensorValue
{
    this(uhd_sensor_value_handle handle)
    {
        _handle = handle;
    }


    @disable this(this);


    ~this()
    {
        if(_handle !is null)
            uhd_sensor_value_free(&_handle);

        _handle = null;
    }


    bool has(T)() @property
    if(is(T == bool) || is(T : long) || is(T : real) || is(T == string))
    {
        uhd_sensor_value_data_type_t type;
        uhd_sensor_value_data_type(_handle, &type);

        if(is(T == bool) && type == UHD_SENSOR_VALUE_BOOLEAN)
            return true;
        else if(is(T : long) && type == UHD_SENSOR_VALUE_INTEGER)
            return true;
        else if(is(T : real) && type == UHD_SENSOR_VALUE_REALNUM)
            return true;
        else if(is(T == string) && type == UHD_SENSOR_VALUE_STRING)
            return true;
        else
            return false;
    }


    T opCast(T)()
    if(is(T == bool) || is(T : long) || is(T : real) || is(T == string))
    {
        static if(is(T == bool)){
            bool value;
            uhd_sensor_value_to_bool(_handle, &value);
            return value;
        }else static if(is(T : long)){
            int value;
            uhd_sensor_value_to_int(_handle, &value).checkUHDError();
            return cast(T)value;
        }else static if(is(T : real)){
            double value;
            uhd_sensor_value_to_realnum(_handle, &value).checkUHDError();
            return value;
        }else static if(is(T == string)){
            return this.to!string();
        }else
            static assert(0, T.stringof ~ " is unsupported.");
    }


    void toString(scope void delegate(const(char)[]) sink)
    {
        import core.stdc.string;

        char[1024] strbuf;
        uhd_sensor_value_to_pp_string(_handle, strbuf.ptr, strbuf.length - 1).checkUHDError();
        size_t len = strlen(strbuf.ptr);
        sink(strbuf[0 .. len]);
    }


  private:
    uhd_sensor_value_handle _handle;
}