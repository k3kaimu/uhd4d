module uhd.capi.usrp.mboard_eeprom;


import uhd.capi.config;
import uhd.capi.error;


extern(C):

struct uhd_mboard_eeprom_t;

alias uhd_mboard_eeprom_handle = uhd_mboard_eeprom_t*;

uhd_error uhd_mboard_eeprom_make(uhd_mboard_eeprom_handle* h);
uhd_error uhd_mboard_eeprom_free(uhd_mboard_eeprom_handle* h);
uhd_error uhd_mboard_eeprom_get_value(uhd_mboard_eeprom_handle h, const char* key, char* value_out, size_t strbuffer_len);
uhd_error uhd_mboard_eeprom_set_value(uhd_mboard_eeprom_handle h, const char* key, const char* value);
uhd_error uhd_mboard_eeprom_last_error(uhd_mboard_eeprom_handle h, char* error_out, size_t strbuffer_len);
