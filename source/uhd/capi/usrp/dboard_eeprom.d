module uhd.capi.usrp.dboard_eeprom;

import uhd.capi.config;
import uhd.capi.error;


extern(C):
nothrow:
@nogc:


struct uhd_dboard_eeprom_t;

alias uhd_dboard_eeprom_handle = uhd_dboard_eeprom_t*;

uhd_error uhd_dboard_eeprom_make(uhd_dboard_eeprom_handle* h);
uhd_error uhd_dboard_eeprom_free(uhd_dboard_eeprom_handle* h);

uhd_error uhd_dboard_eeprom_get_id(uhd_dboard_eeprom_handle h, char* id_out, size_t strbuffer_len);
uhd_error uhd_dboard_eeprom_set_id(uhd_dboard_eeprom_handle h, const char* id);
uhd_error uhd_dboard_eeprom_get_serial(uhd_dboard_eeprom_handle h, char* serial_out, size_t strbuffer_len);
uhd_error uhd_dboard_eeprom_set_serial(uhd_dboard_eeprom_handle h, const char* serial);
uhd_error uhd_dboard_eeprom_get_revision(uhd_dboard_eeprom_handle h, int* revision_out);
uhd_error uhd_dboard_eeprom_set_revision(uhd_dboard_eeprom_handle h, int revision);
uhd_error uhd_dboard_eeprom_last_error(uhd_dboard_eeprom_handle h, char* error_out, size_t strbuffer_len);
