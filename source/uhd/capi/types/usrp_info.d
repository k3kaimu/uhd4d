module uhd.capi.types.usrp_info;

import uhd.capi.config;
import uhd.capi.error;


extern(C):

struct uhd_usrp_rx_info_t
{
    char* mboard_id;
    char* mboard_name;
    char* mboard_serial;
    char* rx_id;
    char* rx_subdev_name;
    char* rx_subdev_spec;
    char* rx_serial;
    char* rx_antenna;
}


struct uhd_usrp_tx_info_t
{
    char* mboard_id;
    char* mboard_name;
    char* mboard_serial;
    char* tx_id;
    char* tx_subdev_name;
    char* tx_subdev_spec;
    char* tx_serial;
    char* tx_antenna;
}

