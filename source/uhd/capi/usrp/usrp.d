module uhd.capi.usrp.usrp;

import core.stdc.time;

import uhd.capi.config;
import uhd.capi.error;
import uhd.capi.types.metadata;
import uhd.capi.types.ranges;
import uhd.capi.types.sensors;
import uhd.capi.types.string_vector;
import uhd.capi.types.tune_request;
import uhd.capi.types.tune_result;
import uhd.capi.types.usrp_info;
import uhd.capi.usrp.mboard_eeprom;
import uhd.capi.usrp.dboard_eeprom;
import uhd.capi.usrp.subdev_spec;


extern(C):
nothrow:
@nogc:

struct uhd_usrp_register_info_t
{
    size_t bitwidth;
    bool readable;
    bool writable;
}


struct uhd_stream_args_t
{
    char* cpu_format;
    char* otw_format;
    char* args;
    size_t* channel_list;
    int n_channels;
}


enum uhd_stream_mode_t
{
    START_CONTINUOUS = 97,
    STOP_CONTINUOUS = 111,
    NUM_SAMPS_AND_DONE = 100,
    NUM_SAMPS_AND_MORE = 109,
}

struct uhd_stream_cmd_t
{
    uhd_stream_mode_t stream_mode;
    size_t num_samps;
    bool stream_now;
    time_t time_spec_full_secs;
    double time_spec_frac_secs;
}

struct uhd_rx_streamer;
struct uhd_tx_streamer;

alias uhd_rx_streamer_handle = shared(uhd_rx_streamer*);
alias uhd_tx_streamer_handle = shared(uhd_tx_streamer*);


uhd_error uhd_rx_streamer_make(uhd_rx_streamer_handle* h);
uhd_error uhd_rx_streamer_free(uhd_rx_streamer_handle* h);
uhd_error uhd_rx_streamer_num_channels(uhd_rx_streamer_handle h, size_t* num_channels_out);
uhd_error uhd_rx_streamer_max_num_samps(uhd_rx_streamer_handle h, size_t* max_num_samps_out);
uhd_error uhd_rx_streamer_recv(uhd_rx_streamer_handle h, void** buffs, size_t samps_per_buff, uhd_rx_metadata_handle* md, double timeout, bool one_packet, size_t* item_recvd);
uhd_error uhd_rx_streamer_issue_stream_cmd(uhd_rx_streamer_handle h, const uhd_stream_cmd_t* stream_cmd);
uhd_error uhd_rx_streamer_last_error(uhd_rx_streamer_handle h, char* error_out, size_t strbuffer_len);

uhd_error uhd_tx_streamer_make(uhd_tx_streamer_handle* h);
uhd_error uhd_tx_streamer_free(uhd_tx_streamer_handle* h);
uhd_error uhd_tx_streamer_num_channels(uhd_tx_streamer_handle h, size_t* num_channels_out);
uhd_error uhd_tx_streamer_max_num_samps(uhd_tx_streamer_handle h, size_t* max_num_samps_out);
uhd_error uhd_tx_streamer_send(uhd_tx_streamer_handle h, const void** buffs, size_t samps_per_buff, uhd_tx_metadata_handle* md, double timeout, size_t* items_sent);
uhd_error uhd_tx_streamer_recv_async_msg(uhd_tx_streamer_handle h, uhd_async_metadata_handle* md, double timeout, bool* valid);
uhd_error uhd_tx_streamer_last_error(uhd_tx_streamer_handle h, char* error_out, size_t strbuffer_len);

struct uhd_usrp;

alias uhd_usrp_handle = shared(uhd_usrp*);

uhd_error uhd_usrp_find(const char* args, uhd_string_vector_handle* strings_out);
uhd_error uhd_usrp_make(uhd_usrp_handle* h, const char* args);
uhd_error uhd_usrp_free(uhd_usrp_handle* h);
uhd_error uhd_usrp_last_error(uhd_usrp_handle h, char* error_out, size_t strbuffer_len);

uhd_error uhd_usrp_get_rx_stream(uhd_usrp_handle h, uhd_stream_args_t* stream_args, uhd_rx_streamer_handle h_out);
uhd_error uhd_usrp_get_tx_stream(uhd_usrp_handle h, uhd_stream_args_t* stream_args, uhd_tx_streamer_handle h_out);

uhd_error uhd_usrp_get_rx_info(uhd_usrp_handle h, size_t chan, uhd_usrp_rx_info_t* info_out);
uhd_error uhd_usrp_get_tx_info(uhd_usrp_handle h, size_t chan, uhd_usrp_tx_info_t* info_out);

uhd_error uhd_usrp_set_master_clock_rate(uhd_usrp_handle h, size_t mboard, double* clock_rate_out);
uhd_error uhd_usrp_get_pp_string(uhd_usrp_handle h, char* pp_string_out, size_t strbuffer_len);
uhd_error uhd_usrp_get_mboard_name(uhd_usrp_handle h, size_t mboard, char* mboard_name_out, size_t strbuffer_len);
uhd_error uhd_usrp_get_time_last_pps(uhd_usrp_handle h, size_t mboard, time_t* full_secs_out, double* frac_secs_out);
uhd_error uhd_usrp_set_time_now(uhd_usrp_handle h, time_t full_secs, double frac_secs, size_t mboard);
uhd_error uhd_usrp_set_time_next_pps(uhd_usrp_handle h, time_t full_secs, double frac_secs, size_t mboard);
uhd_error uhd_usrp_set_time_unknown_pps(uhd_usrp_handle h, time_t full_secs, double frac_secs);
uhd_error uhd_usrp_get_time_synchronized(uhd_usrp_handle h, bool* result_out);
uhd_error uhd_usrp_set_command_time(uhd_usrp_handle h, time_t full_secs, double frac_secs, size_t mboard);
uhd_error uhd_usrp_clear_command_time(uhd_usrp_handle h, size_t mboard);
uhd_error uhd_usrp_set_time_source(uhd_usrp_handle h, const char* time_source, size_t mboard);
uhd_error uhd_usrp_get_time_source(uhd_usrp_handle h, size_t mboard, char* time_source_out, size_t strbuffer_len);
uhd_error uhd_usrp_get_time_sources(uhd_usrp_handle h, size_t mboard, uhd_string_vector_handle* time_sources_out);
uhd_error uhd_usrp_set_clock_source(uhd_usrp_handle h, const char* clock_source, size_t mboard);
uhd_error uhd_usrp_get_clock_source(uhd_usrp_handle h, size_t mboard, char* clock_source_out, size_t strbuffer_t);
uhd_error uhd_usrp_get_clock_sources(uhd_usrp_handle h, size_t mboard, uhd_string_vector_handle* clock_source_out);
uhd_error uhd_usrp_set_clock_source_out(uhd_usrp_handle h, bool enb, size_t mboard);
uhd_error uhd_usrp_set_time_source_out(uhd_usrp_handle h, bool enb, size_t mboard);
uhd_error uhd_usrp_get_num_mboards(uhd_usrp_handle h, size_t* num_mboards_out);
uhd_error uhd_usrp_get_mboard_sensor(uhd_usrp_handle h, const char* name, size_t mboard, uhd_sensor_value_handle* sensor_value_out);
uhd_error uhd_usrp_get_mboard_sensor_names(uhd_usrp_handle h, size_t mboard, uhd_string_vector_handle* mboard_sensor_names_out);
uhd_error uhd_usrp_set_user_register(uhd_usrp_handle h, ubyte addr, uint data, size_t mboard);
uhd_error uhd_usrp_get_mboard_eeprom(uhd_usrp_handle h, uhd_mboard_eeprom_handle mb_eeprom, size_t mboard);
uhd_error uhd_usrp_set_mboard_eeprom(uhd_usrp_handle h, uhd_mboard_eeprom_handle mb_eeprom, size_t mboard);
uhd_error uhd_usrp_get_dboard_eeprom(uhd_usrp_handle h, uhd_dboard_eeprom_handle db_eeprom, const char* unit, const char* slot, size_t mboard);
uhd_error uhd_usrp_set_dboard_eeprom(uhd_usrp_handle h, uhd_dboard_eeprom_handle db_eeprom, const char* unit, const char* slot, size_t mboard);

uhd_error uhd_usrp_set_rx_subdev_spec(uhd_usrp_handle h, uhd_subdev_spec_handle subdev_spec, size_t mboard);
uhd_error uhd_usrp_get_rx_subdev_spec(uhd_usrp_handle h, size_t mboard, uhd_subdev_spec_handle subdev_spec_out);
uhd_error uhd_usrp_get_rx_num_channels(uhd_usrp_handle h, size_t* num_channels_out);
uhd_error uhd_usrp_get_rx_subdev_name(uhd_usrp_handle h, size_t chan, char* rx_subdev_name_out, size_t strbuffer_len);
uhd_error uhd_usrp_set_rx_rate(uhd_usrp_handle h, double rate, size_t chan);
uhd_error uhd_usrp_get_rx_rate(uhd_usrp_handle h, size_t chan, double* rate);
uhd_error uhd_usrp_get_rx_rates(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle rates_out);
uhd_error uhd_usrp_set_rx_freq(uhd_usrp_handle h, uhd_tune_request_t* tune_request, size_t chan, uhd_tune_result_t* tune_result);
uhd_error uhd_usrp_get_rx_freq(uhd_usrp_handle h, size_t chan, double* freq_out);
uhd_error uhd_usrp_get_rx_freq_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle freq_range_out);
uhd_error uhd_usrp_get_fe_rx_freq_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle freq_range_out);
uhd_error uhd_usrp_set_rx_gain(uhd_usrp_handle h, double gain, size_t chan, const char* gain_name);
uhd_error uhd_usrp_set_normalized_rx_gain(uhd_usrp_handle h, double gain, size_t chan);
uhd_error uhd_usrp_set_rx_agc(uhd_usrp_handle h, bool enable, size_t chan);
uhd_error uhd_usrp_get_rx_gain(uhd_usrp_handle h, size_t chanm, const char* gain_name, double* gain_out);
uhd_error uhd_usrp_get_normalized_rx_gain(uhd_usrp_handle h, size_t chan, double* gain_out);
uhd_error uhd_usrp_get_rx_gain_range(uhd_usrp_handle h, const char* name, size_t chan, uhd_meta_range_handle gain_range_out);
uhd_error uhd_usrp_get_rx_gain_names(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* gain_names_out);
uhd_error uhd_usrp_set_rx_antenna(uhd_usrp_handle h, const char* ant, size_t chan);
uhd_error uhd_usrp_get_rx_antenna(uhd_usrp_handle h, size_t chan, char* ant_out, size_t strbuffer_len);
uhd_error uhd_usrp_get_rx_antennas(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* antennas_out);
uhd_error uhd_usrp_get_rx_sensor_names(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* sensor_names_out);
uhd_error uhd_usrp_set_rx_bandwidth(uhd_usrp_handle h, double bandwidth, size_t chan);
uhd_error uhd_usrp_get_rx_bandwidth(uhd_usrp_handle h, size_t chan, double* bandwidth_out);
uhd_error uhd_usrp_get_rx_bandwidth_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle bandwidth_range_out);
uhd_error uhd_usrp_get_rx_sensor(uhd_usrp_handle h, const char* name, size_t chan, uhd_sensor_value_handle* sensor_value_out);
uhd_error uhd_usrp_set_rx_dc_offset_enabled(uhd_usrp_handle h, bool enb, size_t chan);
uhd_error uhd_usrp_set_rx_iq_balance_enabled(uhd_usrp_handle h, bool enb, size_t chan);
uhd_error uhd_usrp_set_tx_subdev_spec(uhd_usrp_handle h, uhd_subdev_spec_handle subdev_spec, size_t mboard);
uhd_error uhd_usrp_get_tx_subdev_spec(uhd_usrp_handle h, size_t mboard, uhd_subdev_spec_handle subdev_spec_out);
uhd_error uhd_usrp_get_tx_num_channels(uhd_usrp_handle h, size_t* num_channels_out);
uhd_error uhd_usrp_get_tx_subdev_name(uhd_usrp_handle h, size_t chan, char* tx_subdev_name_out, size_t strbuffer_len);
uhd_error uhd_usrp_set_tx_rate(uhd_usrp_handle h, double rate, size_t chan);
uhd_error uhd_usrp_get_tx_rate(uhd_usrp_handle h, size_t chan, double* rate_out);
uhd_error uhd_usrp_get_tx_rates(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle rates_out);
uhd_error uhd_usrp_set_tx_freq(uhd_usrp_handle h, uhd_tune_request_t *tune_request, size_t chan, uhd_tune_result_t* tune_result);
uhd_error uhd_usrp_get_tx_freq(uhd_usrp_handle h, size_t chan, double* freq_out);
uhd_error uhd_usrp_get_tx_freq_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle freq_range_out);
uhd_error uhd_usrp_get_fe_tx_freq_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle freq_range_out);
uhd_error uhd_usrp_set_tx_gain(uhd_usrp_handle h, double gain, size_t chan, const char* gain_name);
uhd_error uhd_usrp_set_normalized_tx_gain(uhd_usrp_handle h, double gain, size_t chan);
uhd_error uhd_usrp_get_tx_gain_range(uhd_usrp_handle h, const char* name, size_t chan, uhd_meta_range_handle gain_range_out);
uhd_error uhd_usrp_get_tx_gain(uhd_usrp_handle h, size_t chan, const char* gain_name, double* gain_out);
uhd_error uhd_usrp_get_normalized_tx_gain(uhd_usrp_handle h, size_t chan, double* gain_out);
uhd_error uhd_usrp_get_tx_gain_names(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* gain_names_out);
uhd_error uhd_usrp_set_tx_antenna(uhd_usrp_handle h, const char* ant, size_t chan);
uhd_error uhd_usrp_get_tx_antenna(uhd_usrp_handle h, size_t chan, char* ant_out, size_t strbuffer_len);
uhd_error uhd_usrp_get_tx_antennas(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* antennas_out);
uhd_error uhd_usrp_set_tx_bandwidth(uhd_usrp_handle h, double bandwidth, size_t chan);
uhd_error uhd_usrp_get_tx_bandwidth(uhd_usrp_handle h, size_t chan, double* bandwidth_out);
uhd_error uhd_usrp_get_tx_bandwidth_range(uhd_usrp_handle h, size_t chan, uhd_meta_range_handle bandwidth_range_out);
uhd_error uhd_usrp_get_tx_sensor(uhd_usrp_handle h, const char* name, size_t chan, uhd_sensor_value_handle* sensor_value_out);
uhd_error uhd_usrp_get_tx_sensor_names(uhd_usrp_handle h, size_t chan, uhd_string_vector_handle* sensor_names_out);
uhd_error uhd_usrp_set_tx_dc_offset_enabled(uhd_usrp_handle h, bool enb, size_t chan);
uhd_error uhd_usrp_set_tx_iq_balance_enabled(uhd_usrp_handle h, bool enb, size_t chan);
uhd_error uhd_usrp_get_gpio_banks(uhd_usrp_handle h, size_t mboard, uhd_string_vector_handle* gpio_banks_out);
uhd_error uhd_usrp_set_gpio_attr(uhd_usrp_handle h, const char* bank, const char* attr, uint value, uint mask, size_t mboard);
uhd_error uhd_usrp_get_gpio_attr(uhd_usrp_handle h, const char* bank, const char* attr, size_t mboard, uint* attr_out);
uhd_error uhd_usrp_enumerate_registers(uhd_usrp_handle h, size_t mboard, uhd_string_vector_handle* registers_out);
uhd_error uhd_usrp_get_register_info(uhd_usrp_handle h, const char* path, size_t mboard, uhd_usrp_register_info_t* register_info_out);
uhd_error uhd_usrp_write_register(uhd_usrp_handle h, const char* path, uint field, ulong value, size_t mboard);
uhd_error uhd_usrp_read_register(uhd_usrp_handle h, const char* path, uint field, size_t mboard, ulong* value_out);



