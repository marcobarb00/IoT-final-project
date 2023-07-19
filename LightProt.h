

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

#define CONNECT 1
#define CONNACK 2
#define SUBSCRIBE 3
#define SUBACK 4
#define PUBLISH 5

#define NOTHING 0
#define TEMPERATURE 1
#define HUMIDITY 2
#define LUMINOSITY 3

#define NOT_CONNECTED 0
#define CONNECTED 1

typedef nx_struct msg {
	nx_uint16_t id;
	nx_uint16_t type;
	nx_uint16_t topic;
	nx_uint16_t payload;
} msg_t;

typedef nx_struct communication_channel{
	nx_uint16_t status;
	nx_uint16_t subscribed_topic;
 } communication_channel_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
