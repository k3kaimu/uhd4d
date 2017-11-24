module uhd.capi.usrp_clock.usrp_clock;

import uhd.capi.config;
import uhd.capi.error;
import uhd.capi.types.sensors;
import uhd.capi.types.string_vector;


extern(C):
nothrow:
@nogc:

struct uhd_usrp_clock;

alias uhd_usrp_clock_handle = uhd_usrp_clock*;

uhd_error uhd_usrp_clock_find(const char* args, uhd_string_vector_t* devices_out);
uhd_error uhd_usrp_clock_make(uhd_usrp_clock_handle* h, const char* args);
uhd_error uhd_usrp_clock_free(uhd_usrp_clock_handle* h);
uhd_error uhd_usrp_clock_last_error(uhd_usrp_clock_handle h, char* error_out, size_t strbuffer_len);
uhd_error uhd_usrp_clock_get_pp_string(uhd_usrp_clock_handle h, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_usrp_clock_get_num_boards(uhd_usrp_clock_handle h, size_t* num_boards_out);
uhd_error uhd_usrp_clock_get_time(uhd_usrp_clock_handle h, size_t board, uint* clock_time_out);
uhd_error uhd_usrp_clock_get_sensor(uhd_usrp_clock_handle h, const char* name, size_t board, uhd_sensor_value_handle* sensor_value_out);
uhd_error uhd_usrp_clock_get_sensor_names(uhd_usrp_clock_handle h, size_t board, uhd_string_vector_handle* sensor_names_out);
