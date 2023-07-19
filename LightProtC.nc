
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

  message_t packet;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  
  // communication channels
  communication_channel_t comunication_channels[8];
  
  // function to initialize the communication channels
  // only used by the PANC
  void initialize_communication_channels(){
  	for(int i = 0; i < 8; i++){
  	  communicaiton_channel_t communication_channel;
  	  
  	  communication_channel.id = i+2;
  	  communication_channel.status = 0;
  	  communication_channel.subscribed_topic = NOTHING;
  	  
  	  communication_channels[i] = communication_channel;
  	}
  }
  
  
  // functions to send messages
  
  void send_connect_message(){
  	dbg("radio_pack", "sending a connect message\n");
  	msg_t *connect_message;
    connect_message = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
    
    connect_message->type = CONNECT;
    
    // send the message to node 1 (PANC)
    generate_send(1, &connect_message, 2);
  }
  
  void send_subscribe_message(nx_uint16_t topic){
  	dbg("radio_pack", "sending a subscribe message\n");
  	msg_t *subscribe_message;
    subscribe_message = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
    
    subscribe_message->type = SUBSCRIBE;
    subscribe_message->topic = topic;
    
    // send the message to node 1 (PANC)
    generate_send(1, &subscribe_message, 2);
  }
  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
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
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
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
	  if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
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
		dbg("radio", "PANC radio start done");
		initialize_communication_channels();
	  }
	  else{
	  	dbg("radio", "Node %d: radio on\n", TOS_NODE_ID);
	  	// wait 2s and then send a connect message
	  	timer3.startOneShot(2000);
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
	if(connect_ack = false){
		send_connect_message();
	}
  }
  
  event void Timer2.fired() {
	// timer used to wait for acks of subscribe messages
	if(subscribe_ack = false){
		send_subscribe_message();
	}
  }
  
  event void Timer3.fired() {
    // timer used for simulation purposes
	if(simulation == CONNECT){
		send_connect_message();
	}
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	* Parse the receive packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	* Implement the LED logic and print LED status on Debug
	*/
	
    
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if(error == SUCCESS){
	  dbg("radio_send", "Packet sent...");
	  dbg_clear("radio_send", " at time %s \n", sim_time_string());
	  
	  msg_t *message;
	  message = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
	  
	  if(msg->type == CONNECT){
	  	connect_acked = false;
	  	
	  	// wait 1s to receive an ack for the connect message
	  	call timer1.startOneShot(1000);
	  }
	  
	  if(msg->type == SUBSCRIBE){
	  	subscribe_acked = false;
	  	
	  	// wait 1s to receive an ack for the subscribe message
	  	call timer2.startOneShot(1000);
	  }
	  
	}else
	  dbg("radio_send", "there was an error sending the packet\n");
	  
	locked = FALSE;
  }
}




