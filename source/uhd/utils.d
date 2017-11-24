module uhd.utils;

import core.stdc.time;

import std.datetime;
import std.exception;
import std.typecons;

import uhd.capi.error;


class UHDException : Exception
{
    mixin basicExceptionCtors;
}


void checkUHDError(uhd_error error)
{
    final switch(error)
    {
        case uhd_error.NONE:
            return;

        case uhd_error.INVALID_DEVICE:
        case uhd_error.INDEX:
        case uhd_error.KEY:
        case uhd_error.NOT_IMPLEMENTED:
        case uhd_error.USB:
        case uhd_error.IO:
        case uhd_error.OS:
        case uhd_error.ASSERTION:
        case uhd_error.LOOKUP:
        case uhd_error.TYPE:
        case uhd_error.VALUE:
        case uhd_error.RUNTIME:
        case uhd_error.ENVIRONMENT:
        case uhd_error.SYSTEM:
        case uhd_error.EXCEPT:
        case uhd_error.BOOSTEXCEPT:
        case uhd_error.STDEXCEPT:
        case uhd_error.UNKNOWN:
            import std.conv : to;

            char[] buf = new char[1024];
            uhd_get_last_error(buf.ptr, buf.length-1);
            throw new UHDException(buf.ptr.to!string);
    }
}


struct VUHDException
{
    this(uhd_error error) nothrow @nogc
    {
        if(error == uhd_error.NONE){
            _init = false;
            _error = error;
        }else{
            _init = true;
            _error = error;
        }
    }


    bool opCast(T : bool)() const nothrow @nogc
    {
        return _init;
    }


    UHDException makeException() @property
    {
        if(!_init) return null;

        import std.conv : to;
        char[] buf = new char[1024];
        uhd_get_last_error(buf.ptr, buf.length-1);
        return new UHDException(buf.ptr.to!string);
    }


    void print() nothrow @nogc
    {
        import core.stdc.stdio : puts;

        char[2048] buf;
        uhd_get_last_error(buf.ptr, buf.length - 1);
        puts(buf.ptr);
    }


    alias makeException this;


  private:
    bool _init;
    uhd_error _error;
}


Tuple!(time_t, real) splitToFullAndFracSecs(Duration time)
{
    auto s_ns = time.split!("seconds", "nsecs");

    return typeof(return)(s_ns.seconds, s_ns.nsecs / 1.0E-9L);
}


Duration toDuration(time_t fullSecs, real fracSecs)
{
    import std.math : floor;

    Duration time = fullSecs.seconds;
    time += (cast(long)floor(fracSecs * 1E9L)).nsecs;

    return time;
}
