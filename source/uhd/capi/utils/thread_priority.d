module uhd.capi.utils.thread_priority;

import uhd.capi.config;
import uhd.capi.error;


extern(C):
nothrow:
@nogc:


enum float uhd_default_thread_priority = 0.5;


uhd_error uhd_set_thread_priority(
    float priority,
    bool realtime
);
