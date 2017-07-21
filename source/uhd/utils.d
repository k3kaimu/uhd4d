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


Tuple!(time_t, double) splitToUnixTime(SysTime time)
{
    auto unixTime = time.toUnixTime();
    auto fracSecs = time.fracSecs.total!"nsecs" * 1.0  / 1.0E-9;

    return typeof(return)(unixTime, fracSecs);
}


SysTime toSysTime(time_t fullSecs, double fracSecs)
{
    SysTime time = SysTime.fromUnixTime(fullSecs);
    time += (cast(long)(fracSecs * 1E9)).nsecs;

    return time;
}
