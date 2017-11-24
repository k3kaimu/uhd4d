module uhd.capi.usrp.subdev_spec;


import uhd.capi.config;
import uhd.capi.error;


extern(C):
nothrow:
@nogc:


struct uhd_subdev_spec_pair_t
{
    char* db_name;
    char* sd_name;
}


struct uhd_subdev_spec_t;
alias uhd_subdev_spec_handle = uhd_subdev_spec_t*;

uhd_error uhd_subdev_spec_pair_free(uhd_subdev_spec_pair_t* subdev_spec_pair);
uhd_error uhd_subdev_spec_pairs_equal(const uhd_subdev_spec_pair_t* first,
                                      const uhd_subdev_spec_pair_t* second,
                                      bool* result_out);
uhd_error uhd_subdev_spec_make(uhd_subdev_spec_handle* h, const char* markup);
uhd_error uhd_subdev_spec_free(uhd_subdev_spec_handle* h);
uhd_error uhd_subdev_spec_size(uhd_subdev_spec_handle h, size_t* size_out);
uhd_error uhd_subdev_spec_push_back(uhd_subdev_spec_handle h, const char* markup);
uhd_error uhd_subdev_spec_at(uhd_subdev_spec_handle h, size_t num, uhd_subdev_spec_pair_t* subdev_spec_pair_out);
uhd_error uhd_subdev_spec_to_pp_string(uhd_subdev_spec_handle h, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_subdev_spec_to_string(uhd_subdev_spec_handle h, char* string_out, size_t strbuffer_len);
uhd_error uhd_subdev_spec_last_error(uhd_subdev_spec_handle h, char* error_out, size_t strbuffer_len);
