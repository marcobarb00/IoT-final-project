

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

typedef nx_struct radio_route_msg {
	nx_uint16_t type;
	nx_uint16_t topic;
	nx_uint16_t payload;
} radio_route_msg_t;

typedef nx_struct comunication_channel{
	nx_uint16_t id;
	nx_uint16_t status;
	nx_uint16_t subscribed_topic;
 } comunication_channel_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
