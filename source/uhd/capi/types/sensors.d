module uhd.capi.types.sensors;

import uhd.capi.config;
import uhd.capi.error;


extern(C):
nothrow:
@nogc:


struct uhd_sensor_value_t;

alias uhd_sensor_value_handle = uhd_sensor_value_t*;

enum uhd_sensor_value_data_type_t
{
    UHD_SENSOR_VALUE_BOOLEAN = 98,
    UHD_SENSOR_VALUE_INTEGER = 105,
    UHD_SENSOR_VALUE_REALNUM = 114,
    UHD_SENSOR_VALUE_STRING = 115,
}

uhd_error uhd_sensor_value_make_from_bool(uhd_sensor_value_handle* h,
    const char* name, bool value, const char* utrue, const char* ufalse);
uhd_error uhd_sensor_value_make_from_int(uhd_sensor_value_handle* h,
    const char* name, int value, const char* unit, const char* formatter);
uhd_error uhd_sensor_value_make_from_realnum(uhd_sensor_value_handle* h,
    const char* name, double value, const char* unit, const char* formatter);
uhd_error uhd_sensor_value_make_from_string(uhd_sensor_value_handle* h,
    const char* name, const char* value, const char* unit);

uhd_error uhd_sensor_value_free(uhd_sensor_value_handle* h);
uhd_error uhd_sensor_value_to_bool(uhd_sensor_value_handle h, bool* value_out);
uhd_error uhd_sensor_value_to_int(uhd_sensor_value_handle h, int* value_out);
uhd_error uhd_sensor_value_to_realnum(uhd_sensor_value_handle h, double* value_out);
uhd_error uhd_sensor_value_name(uhd_sensor_value_handle h, char* name_out, size_t strbuffer_len);
uhd_error uhd_sensor_value_value(uhd_sensor_value_handle h, char* value_out, size_t strbuffer_len);
uhd_error uhd_sensor_value_unit(uhd_sensor_value_handle h, char* uint_out, size_t strbuffer_len);
uhd_error uhd_sensor_value_data_type(uhd_sensor_value_handle h, uhd_sensor_value_data_type_t* data_type_out);
uhd_error uhd_sensor_value_to_pp_string(uhd_sensor_value_handle h, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_sensor_value_last_error(uhd_sensor_value_handle h, char* error_out, size_t strbuffer_len);
