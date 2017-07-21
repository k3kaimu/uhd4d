module uhd.capi.types.metadata;

import core.stdc.time;

import uhd.capi.config;
import uhd.capi.error;


struct uhd_rx_metadata_t;
struct uhd_tx_metadata_t;
struct uhd_async_metadata_t;

extern(C):

alias uhd_rx_metadata_handle = uhd_rx_metadata_t*;
alias uhd_tx_metadata_handle = uhd_tx_metadata_t*;
alias uhd_async_metadata_handle = uhd_async_metadata_t*;


enum uhd_rx_metadata_error_code_t
{
    UHD_RX_METADATA_ERROR_CODE_NONE = 0x0,
    UHD_RX_METADATA_ERROR_CODE_TIMEOUT = 0x1,
    UHD_RX_METADATA_ERROR_CODE_LATE_COMMAND = 0x2,
    UHD_RX_METADATA_ERROR_CODE_BROKEN_CHAIN = 0x4,
    UHD_RX_METADATA_ERROR_CODE_OVERFLOW = 0x8,
    UHD_RX_METADATA_ERROR_CODE_ALIGNMENT = 0xC,
    UHD_RX_METADATA_ERROR_CODE_BAD_PACKET = 0xF,
}

uhd_error uhd_rx_metadata_make(uhd_rx_metadata_handle* handle);
uhd_error uhd_rx_metadata_free(uhd_rx_metadata_handle* handle);
uhd_error uhd_rx_metadata_has_time_spec(uhd_rx_metadata_handle h, bool* result_out);
uhd_error uhd_rx_metadata_time_spec(uhd_rx_metadata_handle h, time_t* full_secs_out, double* frac_secs_out);
uhd_error uhd_rx_metadata_more_fragments(uhd_rx_metadata_handle h, bool* result_out);
uhd_error uhd_rx_metadata_fragment_offset(uhd_rx_metadata_handle h, size_t* fragment_offset_out);
uhd_error uhd_rx_metadata_start_of_burst(uhd_rx_metadata_handle h, bool* result_out);
uhd_error uhd_rx_metadata_end_of_burst(uhd_rx_metadata_handle h, bool* result_out);
uhd_error uhd_rx_metadata_out_of_sequence(uhd_rx_metadata_handle h, bool* result_out);

uhd_error uhd_rx_metadata_error_code(uhd_rx_metadata_handle h, uhd_rx_metadata_error_code_t* error_code_out);
uhd_error uhd_rx_metadata_strerror(uhd_rx_metadata_handle h, char* strerror_out, size_t strbuffer_len);
uhd_error uhd_rx_metadata_last_error(uhd_rx_metadata_handle h, char* error_out, size_t strbuffer_len);

uhd_error uhd_tx_metadata_make(uhd_tx_metadata_handle* handle, bool has_time_spec, time_t full_secs, double frac_secs, bool start_of_burst, bool end_of_burst);
uhd_error uhd_tx_metadata_free(uhd_tx_metadata_handle* handle);
uhd_error uhd_tx_metadata_has_time_spec(uhd_tx_metadata_handle h, bool* result_out);
uhd_error uhd_tx_metadata_time_spec(uhd_tx_metadata_handle h, time_t* full_secs_out, double* frac_secs_out);
uhd_error uhd_tx_metadata_start_of_burst(uhd_tx_metadata_handle h, bool* result_out);
uhd_error uhd_tx_metadata_end_of_burst(uhd_tx_metadata_handle h, bool* result_out);
uhd_error uhd_tx_metadata_last_error(uhd_tx_metadata_handle h, char* error_out, size_t strbuffer_len);

enum uhd_async_metadata_event_code_t
{
    UHD_ASYNC_METADATA_EVENT_CODE_BURST_ACK = 0x1,
    UHD_ASYNC_METADATA_EVENT_CODE_UNDERFLOW = 0x2,
    UHD_ASYCN_METADATA_EVENT_CODE_SEQ_ERROR = 0x4,
    UHD_ASYNC_METADATA_EVENT_CODE_TIME_ERROR = 0x8,
    UHD_ASYCN_METADATA_EVENT_CODE_UNDERFLOW_IN_PACKET = 0x10,
    UHD_ASYNC_METADATA_EVENT_CODE_SEQ_ERROR_IN_BURST = 0x20,
    UHD_ASYNC_METADATA_EVENT_CODE_USER_PAYLOAD = 0x40,
}

uhd_error uhd_async_metadata_make(uhd_async_metadata_handle* handle);
uhd_error uhd_async_metadata_free(uhd_async_metadata_handle* handle);
uhd_error uhd_async_metadata_channel(uhd_async_metadata_handle h, size_t* channel_out);
uhd_error uhd_async_metadata_has_time_spec(uhd_async_metadata_handle h, bool* result_out);
uhd_error uhd_asycn_metadata_time_spec(uhd_async_metadata_handle h, time_t* full_secs_out, double* frac_secs_out);
uhd_error uhd_async_metadata_event_code(uhd_async_metadata_handle h, uhd_async_metadata_event_code_t* event_code_out);
uhd_error uhd_async_metadata_user_payload(uhd_async_metadata_handle h, uint* user_payload_out);
uhd_error uhd_async_metadata_last_error(uhd_async_metadata_handle h, char* error_out, size_t strbuffer_len);
