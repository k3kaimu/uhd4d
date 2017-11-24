module uhd.capi.types.tune_request;

import uhd.capi.config;


extern(C):
nothrow:
@nogc:


enum uhd_tune_request_policy_t
{
    NONE = 78,
    AUTO = 65,
    MANUAL = 77,
}

struct uhd_tune_request_t
{
    double target_freq;
    uhd_tune_request_policy_t rf_freq_policy;
    double rf_freq;
    uhd_tune_request_policy_t dsp_freq_policy;
    double dsp_freq;
    char* args;
}
