module uhd.capi.types.ranges;

import uhd.capi.config;
import uhd.capi.error;

extern(C):
nothrow:
@nogc:


struct uhd_range_t
{
    double start;
    double stop;
    double step;
}


struct uhd_meta_range_t;
alias uhd_meta_range_handle = uhd_meta_range_t*;

uhd_error uhd_range_to_pp_string(const uhd_range_t* range, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_meta_range_make(uhd_meta_range_handle* h);
uhd_error uhd_meta_range_free(uhd_meta_range_handle* h);
uhd_error uhd_meta_range_start(uhd_meta_range_handle h, double* start_out);
uhd_error uhd_meta_range_stop(uhd_meta_range_handle h, double* stop_out);
uhd_error uhd_meta_range_step(uhd_meta_range_handle h, double* step_out);
uhd_error uhd_meta_range_clip(uhd_meta_range_handle h, double value, bool clip_step, double* result_out);
uhd_error uhd_meta_range_size(uhd_meta_range_handle h, size_t* size_out);
uhd_error uhd_meta_range_push_back(uhd_meta_range_handle h, const uhd_range_t* range);
uhd_error uhd_meta_range_at(uhd_meta_range_handle h, size_t num, uhd_range_t* range_out);
uhd_error uhd_meta_range_to_pp_string(uhd_meta_range_handle h, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_meta_range_last_error(uhd_meta_range_handle h, char* error_out, size_t strbuffer_len);
