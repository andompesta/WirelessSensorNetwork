#include <Timer.h>
#include "DataMsg.h"
#include "TreeBuilding.h"

module DataCollectionP
{
    uses{
        interface Timer<TMilli> as TimerSend;
        interface Timer<TMilli> as SendInterval;
        interface Boot;
        interface Packet;
        interface AMPacket;
        interface AMSend;
        interface SplitControl as AMControl;
        interface Receive;
        interface Random;
        interface Queue<DataMsg> as Queue;
        interface Queue<DataMsg> as QueueSend;
        interface TreeConnection;
    }
}
implementation
{

    message_t pkt;
    bool send;
    parent_data parent_buf[BUFFER_SIZE];
    uint8_t parent_n;   //number of parent that i have
    uint8_t index_rount_robin;  //last parent that i send 
    num_msg num_buffer[BUFFER_SIZE];
    uint8_t seq_no;
	uint8_t cost;
    uint8_t num_drop_meg;

    task void forwardMessage();



    void round_robin(){
    	DataMsg temp_msg; 
        uint8_t queue_size = call Queue.size();
        dbg("routing", "start round robin procedure \n");
        while(queue_size > 0) {
            if( parent_buf[index_rount_robin].parent != INF  && parent_n != 0 ){
            	temp_msg = call Queue.dequeue();
                temp_msg.address = parent_buf[index_rount_robin].parent;
                dbg("routing", "%u send message to address %u \n",TOS_NODE_ID,temp_msg.address);
                call QueueSend.enqueue(temp_msg);
                index_rount_robin ++;   //i have to send at the next parent
                index_rount_robin =  index_rount_robin % parent_n;
                queue_size --;
                
            }
            else{
            	//clear the sendig queue because i have no parent
            	uint8_t i = 0;
            	for(i = 0; i < queue_size; i++)
            	{
            		call Queue.dequeue();
            	}
            	queue_size = 0;
            	dbg("routing", "----------No parent, clearing queue!!--------- \n");
            }
        }
    }
    

    event void Boot.booted(){
        send = FALSE;
        seq_no = INF;
        cost = INF;
        parent_n = 0;
        index_rount_robin = 0;
        if(!TOS_NODE_ID == 0){
            memset (parent_buf, 0, sizeof(parent_data) * BUFFER_SIZE);
            memset (num_buffer, 0, sizeof(num_msg) * BUFFER_SIZE);
        }
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err){
        if (err == SUCCESS)
        {
            //periodicali send messages
            if(TOS_NODE_ID != 0)
            	call SendInterval.startPeriodic(R_R_PERIOD);
        }
        if (err != SUCCESS)
            call AMControl.start();
    }

    event void AMControl.stopDone(error_t err){}

    task void forwardMessage(){
    	if(send == TRUE){
    		dbg("routing", "Waiting\n");
    		//resending random time
    		call TimerSend.startOneShot(call Random.rand16()%80);
    	}
    	else
    	{	
    		uint8_t queue_size = call QueueSend.size();
    		if(queue_size > 0){
    			error_t error;
          		DataMsg* dataMsg = (DataMsg*) (call Packet.getPayload(&pkt, NULL));
          		DataMsg temp = (DataMsg) call QueueSend.head();
          		*dataMsg = temp;
                if ((error = call AMSend.send(temp.address, &pkt ,sizeof(DataMsg))) == SUCCESS){
        		    send = TRUE;
        		    dbg("routing", "Sending messagge to %u----> source: %u | address: %u \n",temp.address,temp.source,temp.address);
        		} 
        		else {
        		    dbg("routing", "\n\n\n\nERROR\t%u\n", error);
                    send = FALSE;
        		}
            }
        }
    }

  event void AMSend.sendDone(message_t* msg, error_t error)
  {
  	if (error == SUCCESS){  
        //DataMsg* send_msg;
        uint8_t i = 0;    
    	
    	send = FALSE;
        call QueueSend.dequeue();
        for(i = 0; i < BUFFER_SIZE ; i++){
            
            if ( call AMPacket.destination(msg) == num_buffer[i].parent )
            {
                num_buffer[i].num_msg_send++;
            }
        }
        if( call QueueSend.size() > 0 ){
        	call TimerSend.startOneShot(call Random.rand16()%100);
        }
        else
        {
            dbg("routing", "------------------ Stop sending messages --------------\n");
            for(i  = 0; i < BUFFER_SIZE; i++)
            {
                if( num_buffer[i].parent != INF )
                    dbg("routing", "num_msg_send: %u | parent: %u \n", num_buffer[i].num_msg_send, num_buffer[i].parent);
            }
            dbg("routing", "num_drop_meg : %u \n",num_drop_meg);
        }
    }
    else
  	{
  		send = FALSE;
  		dbg("routing", "\n\n\n\nERROR\t%u\n", error);
  		call TimerSend.startOneShot(call Random.rand16()%80);
  	}
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
  { 
  	uint8_t queue_size = 0;
    if (len == sizeof(DataMsg)){
    DataMsg* recivedMsg = (DataMsg*) payload;
        if( TOS_NODE_ID == 0 ){
            dbg("routing", "Message arrived at the sink---> source:%u | address:%u \n",recivedMsg->source,recivedMsg->address);
        }
        else{
            //salva il messaggio in coda
            queue_size = call Queue.size();
            if((queue_size+1) < Q_SIZE){
                call Queue.enqueue( *((DataMsg*) recivedMsg ));
                dbg("routing", "Data recieved---> source:%u | address:%u \n", recivedMsg->source, recivedMsg->address);
            }
            else{
                num_drop_meg ++;
            }
        }
    		
    }
    return msg;
  }


    event void SendInterval.fired(){
        //I have to send messagges to my parent
        if (call Queue.size() > 0)
        {
            round_robin();
            call TimerSend.startOneShot(call Random.rand16()%300);
        }
    }

    event void TimerSend.fired(){
        if (!send ){
            post forwardMessage();
        }   
    }

    event void TreeConnection.parentUpdate(parent_data parent_b[BUFFER_SIZE]){
    	//uint8_t j = 0;
        memcpy(parent_buf,parent_b, sizeof(parent_data) * BUFFER_SIZE );
        parent_n = 0;
        index_rount_robin = 0;
        
        if( seq_no != parent_buf[0].seq_no ){
       		uint8_t i = 0;
            DataMsg temp_msg;
            num_drop_meg = 0;
            cost = parent_buf[0].cost;
            dbg("routing", "New Tree costruction\n");
            
            temp_msg.source = TOS_NODE_ID;
            temp_msg.address = INF;
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            call Queue.enqueue(temp_msg);
            
            seq_no = parent_buf[0].seq_no;
            for(i = 0; i < BUFFER_SIZE; i ++){
	            if( parent_buf[i].parent != INF ){
	                parent_n ++;
	                num_buffer[i].parent = parent_buf[i].parent;
	                num_buffer[i].num_msg_send = 0;
	                dbg("routing","Cost = %u\t Seq_no = %u\t Parent = %u\n",parent_buf[i].cost,parent_buf[i].seq_no,parent_buf[i].parent);
	            }
	            else{
	                num_buffer[i].parent = INF;
	                num_buffer[i].num_msg_send = 0;
	            }
	            
	        }
        }
        else{
        	uint8_t i = 0;
        	dbg("routing","new parent found\n");
        	
        	if(  cost > parent_buf[0].cost ){
        		//I found a parent with a less cost
        		for(i = 0; i < BUFFER_SIZE; i ++){
		        	if( parent_buf[i].parent != INF )
		        	{
		        		parent_n++;
	                	dbg("routing","Cost = %u\t Seq_no = %u\t Parent = %u\n",parent_buf[i].cost,parent_buf[i].seq_no,parent_buf[i].parent); 
		        		num_buffer[i].parent = parent_buf[i].parent;
	                	num_buffer[i].num_msg_send = 0;
		            }
		            else{
		            	num_buffer[i].parent = INF;
	                	num_buffer[i].num_msg_send = 0;
					}
		        }
        	}
        	else{
				for(i = 0; i < BUFFER_SIZE; i ++){
		        	if( parent_buf[i].parent != INF )
		        	{
		        		parent_n++;
	                	dbg("routing","Cost = %u\t Seq_no = %u\t Parent = %u\n",parent_buf[i].cost,parent_buf[i].seq_no,parent_buf[i].parent); 
		        		//dbg("routing","Cost = %u\t Seq_no = %u\t Parent = %u\n",parent_buf[i].cost,parent_buf[i].seq_no,parent_buf[i].parent);
		        		if( parent_buf[i].parent != num_buffer[i].parent ){
			            	num_buffer[i].parent = parent_buf[i].parent;
	                		num_buffer[i].num_msg_send = 0;
	            		}
		            }
		        }	        	
        	}
	   	}
    }
}
