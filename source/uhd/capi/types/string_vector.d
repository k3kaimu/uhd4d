module uhd.capi.types.string_vector;


import uhd.capi.config;
import uhd.capi.error;


extern(C):
nothrow:
@nogc:


struct uhd_string_vector_t;

alias uhd_string_vector_handle = uhd_string_vector_t*;

uhd_error uhd_string_vector_make(uhd_string_vector_handle* h);
uhd_error uhd_string_vector_free(uhd_string_vector_handle* h);
uhd_error uhd_string_vector_push_back(uhd_string_vector_handle* h, const char* value);
uhd_error uhd_string_vector_at(uhd_string_vector_handle h, size_t index, char* value_out, size_t strbuffer_len);
uhd_error uhd_string_vector_size(uhd_string_vector_handle h, size_t* size_out);
uhd_error uhd_string_vector_last_error(uhd_string_vector_handle h, char* error_out, size_t strbuffer_len);
