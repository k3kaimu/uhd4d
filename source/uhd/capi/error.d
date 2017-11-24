module uhd.capi.error;


extern(C):
@nogc:
nothrow:

enum uhd_error
{
    NONE = 0,
    INVALID_DEVICE = 1,
    INDEX = 10,
    KEY = 11,
    NOT_IMPLEMENTED = 20,
    USB = 21,
    IO = 30,
    OS = 31,
    ASSERTION = 40,
    LOOKUP = 41,
    TYPE = 42,
    VALUE = 43,
    RUNTIME = 44,
    ENVIRONMENT = 45,
    SYSTEM = 46,
    EXCEPT = 47,

    BOOSTEXCEPT = 60,
    STDEXCEPT = 70,
    UNKNOWN = 100,
}


uhd_error uhd_get_last_error(char* error_out, size_t strbuffer_len);
