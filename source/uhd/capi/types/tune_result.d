module uhd.capi.types.tune_result;

import uhd.capi.config;


extern(C):
nothrow:
@nogc:


struct uhd_tune_result_t
{
    double clipped_rf_freq;
    double target_rf_freq;
    double actual_rf_freq;
    double target_dsp_freq;
    double actual_dsp_freq;
}
