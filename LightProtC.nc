
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "LightProt.h"


module LightProtC @safe() {
  uses {
  
    /****** INTERFACES *****/
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1; // used for waiting the ack of connect messages
    interface Timer<TMilli> as Timer2; // used for waiting the ack of subscribe messages
    interface Timer<TMilli> as Timer3; // used simulation
    interface SplitControl as AMControl;
    interface Packet;
  }
}
implementation {

  message_t packet_buf;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  
  uint16_t time_delays[9] = {200, 237, 297, 371, 390, 420, 473, 530, 568}; //Time delay in milli seconds
  
  
  bool connect_sent = FALSE;
  bool connack_sent = FALSE;
  bool subscribe_sent = FALSE;
  bool suback_sent = FALSE;
  bool publish_sent = FALSE;
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint16_t type);
  
  // communication channels
  communication_channel_t communication_channels[8];
  
  // acknowledgement booleans
  bool connect_acked = FALSE;
  bool subscribe_acked = FALSE;
  
  // subscribe variable
  uint16_t subscribe_topic = NOTHING;
  
  // simulation variables
  uint16_t simulation = CONNECT;
  
  // function to initialize the communication channels
  // only used by the PANC
  void initialize_communication_channels(){
    int i = 0;
    communication_channel_t communication_channel;
    
  	while(i < 8){
  	  communication_channel.status = 0;
  	  communication_channel.subscribed_topic = NOTHING;
  	  
  	  communication_channels[i] = communication_channel;
  	  
  	  i++;
  	}
  }
  
  
  // functions to send messages
  
  void send_connect_message(){
  	msg_t *connect_message;
  	
  	dbg("radio_pack", "sending a connect message\n");
  	
    connect_message = (msg_t*)call Packet.getPayload(&packet_buf, sizeof(msg_t));
    
    connect_message->id = TOS_NODE_ID;
    connect_message->type = CONNECT;
    
    // send the message to node 1 (PANC)
    generate_send(1, &packet_buf, CONNECT);
  }
  
  void send_connack_message(int id){
  	msg_t *connack_message;
  	
  	dbg("radio_pack", "sending a connack message to mote: %d \n", id);
  	
    connack_message = (msg_t*)call Packet.getPayload(&packet_buf, sizeof(msg_t));
    
    connack_message->type = CONNACK;
    
    // send the message to node with the id specified
    generate_send(id, &packet_buf, CONNACK);
  }
  
  void send_subscribe_message(nx_uint16_t topic){
  	msg_t *subscribe_message;
  	
  	dbg("radio_pack", "sending a subscribe message\n");
  	
    subscribe_message = (msg_t*)call Packet.getPayload(&packet_buf, sizeof(msg_t));
    
    subscribe_message->id = TOS_NODE_ID;
    subscribe_message->type = SUBSCRIBE;
    subscribe_message->topic = topic;
    
    // send the message to node 1 (PANC)
    generate_send(1, &packet_buf, SUBSCRIBE);
  }
  
  
  bool generate_send (uint16_t address, message_t* packet, uint16_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == CONNECT && !connect_sent){
  		connect_sent = TRUE;
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == CONNACK && !connack_sent){
  	  	connack_sent = TRUE;
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == SUBSCRIBE && !subscribe_sent){
  	  	subscribe_sent = TRUE;
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;
  		}else if (type == SUBACK && !suback_sent){
  	  	suback_sent = TRUE;
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;
    }else if (type == PUBLISH && !publish_sent){
    	publish_sent = TRUE;
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot(time_delays[TOS_NODE_ID-1]);
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  bool actual_send (uint16_t address, message_t* packet){
	if(!locked){
	  if (call AMSend.send(address, packet, sizeof(msg_t)) == SUCCESS) {
		dbg("radio_send", "Sending packet");
		locked = TRUE;
		dbg_clear("radio_send", " at time %s \n", sim_time_string());
		return TRUE;
	  }
	}
	return FALSE;
  }
  
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
	  if (TOS_NODE_ID == 1){
		dbg("radio", "PANC radio start done\n");
		initialize_communication_channels();
	  }
	  else{
	  	dbg("radio", "Node %d: radio start done\n", TOS_NODE_ID);
	  	// wait 2s and then send a connect message
	  	call Timer3.startOneShot(2000);
	  }
	}
	else {
	  dbgerror("radio", "Node %d: radio failed to start, retrying...\n", TOS_NODE_ID);
	  call AMControl.start();
	}
  }

  event void AMControl.stopDone(error_t err) {
	dbg("radio", "node %d: radio stopped\n", TOS_NODE_ID);
  }
  
  event void Timer1.fired() {
	// timer used to wait for acks of connect messages
	dbg("timer", "node %d did not receive a CONNACK in time\n", TOS_NODE_ID);
	if(connect_acked == FALSE){
		send_connect_message();
	}
  }
  
  event void Timer2.fired() {
	// timer used to wait for acks of subscribe messages
	if(subscribe_acked == FALSE){
      dbg("timer", "node %d did not receive a SUBACK in time\n", TOS_NODE_ID);
      send_subscribe_message(subscribe_topic);
	}
  }
  
  event void Timer3.fired() {
    // timer used for simulation purposes
	if(simulation == CONNECT){
		send_connect_message();
	}
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    msg_t* message = (msg_t*)payload;
    uint16_t id = message->id;
    communication_channel_t communication_channel = communication_channels[id-2];
	
	if(TOS_NODE_ID == 1){
	  if(message->type == CONNECT){
	  	if(communication_channel.status == NOT_CONNECTED){
	  	  send_connack_message(id);
	  	}else{
	  	  dbg("radio_rec", "node %d already connected, dropping connect packet\n", id);
	  	}
	  }
	}else{
	  if(message->type == CONNACK){
	    dbg("radio_rec", "CONNACK received\n");
	    connect_acked = TRUE;
	  }
	}
	
    return bufPtr;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    msg_t *message;
    
    if(error == SUCCESS){      
	  dbg("radio_send", "Packet sent...");
	  dbg_clear("radio_send", " at time %s \n", sim_time_string());
	  
	  message = (msg_t*)call Packet.getPayload(&packet_buf, sizeof(msg_t));
	  
	  if(message->type == CONNECT){
	    dbg("radio_send", "packet sent was of type CONNECT\n");
	  	
	  	// reset the connect_sent flag
		connect_sent = FALSE;
	  	
	    connect_acked = FALSE;
	    
	  	// wait 1s to receive an ack for the connect message
	  	call Timer1.startOneShot(1000);
	  }
	  
	  if(message->type == CONNACK){
	    dbg("radio_send", "packet sent was of type CONNACK\n");
	  	// reset the connack_sent flag
		connack_sent = FALSE;
	  }
	  
	  if(message->type == SUBSCRIBE){
	  	dbg("radio_send", "packet sent was of type SUBSCRIBE\n");
	  	
	  	// reset the subscribe_sent flag
		subscribe_sent = FALSE;
		
		subscribe_acked = FALSE;
	  	
	  	// wait 1s to receive an ack for the subscribe message
	  	call Timer2.startOneShot(1000);
	  }
	  
	  if(message->type == SUBACK){
	    dbg("radio_send", "packet sent was of type SUBACK\n");
	  	// reset the suback_sent flag
		suback_sent = FALSE;
	  }
	}else
	  dbg("radio_send", "there was an error sending the packet\n");
	  
	locked = FALSE;
  }
}




