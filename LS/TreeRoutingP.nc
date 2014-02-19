#include <Timer.h>
#include "TreeBuilding.h"

module TreeRoutingP
{

    provides{
        interface TreeConnection;
    }
    uses{
        interface Timer<TMilli> as TimerRefresh;
        interface Timer<TMilli> as TimerReSend;
        interface Timer<TMilli> as TimerStart;
        interface Timer<TMilli> as TimerStopSending;
        interface Boot;
        interface Packet;
        interface AMPacket;
        interface AMSend;
        interface SplitControl as AMControl;
        interface Receive;
        interface Random;
    }
}
implementation
{
    message_t pkt;
    bool busy;  //if i'm busy to send messages
    uint16_t index_buffer; //index of how many parent i have(max 4)
    uint16_t distance; //distance form the sink
    uint16_t current_seq_no;    //number of the tree rebuild
    parent_data parent_buffer[BUFFER_SIZE];

    task void sendNotification();
    
    event void Boot.booted(){
        if( TOS_NODE_ID == 0 ){
            busy = FALSE;
            distance = 0;
            current_seq_no = 0;
        }
        else if(! TOS_NODE_ID == 0 ){
            uint8_t i = 0;
            memset (parent_buffer, 0, sizeof(parent_data) * BUFFER_SIZE);
            for( i = 0 ; i < BUFFER_SIZE; i ++){
                parent_buffer[i].cost = INF;
                parent_buffer[i].seq_no = INF;
            	parent_buffer[i].parent = INF;
            }
            busy = FALSE;
            distance = INF;
            current_seq_no = 0;
        }
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err){
        if (err == SUCCESS){
            if (TOS_NODE_ID == 0){
                //start the construction of the tree form the sink
                call TimerStart.startOneShot(START_PERIOD);
            }
        }
        else {
          call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err){}

    task void sendNotification(){
        if ( !busy )
        {
            TreeBuilding* msg = (TreeBuilding*) (call Packet.getPayload(&pkt, NULL));
            error_t error;
            msg->cost = (distance + 1); // the cost is the distance from the sink plus 1 hop(this one)
            msg->seq_no = current_seq_no;
        /*     dbg("routing", "NOT\tSEQ\t%u\tCOST\t%u\n", current_seq_no, current_cost); */
            if ((error = call AMSend.send(AM_BROADCAST_ADDR, &pkt,sizeof(TreeBuilding))) == SUCCESS){
                busy = TRUE;
                //dbg("routing", "Traing to send a message \n");
            } 
            else {
                dbg("routing", "\n\n\n\nERROR\t%u\n", error);
                busy = FALSE;
                if(TOS_NODE_ID != 0)
                    call TimerReSend.startOneShot(call Random.rand16()%100);   //try to resend messages at a rendom time
            }
        }
        else{
            dbg("routing", "Node busy!!!!! retry \n");
            if(TOS_NODE_ID != 0)
                call TimerReSend.startOneShot(call Random.rand16()%100);
        }
    }

    event void TimerRefresh.fired(){
        dbg("routing", "refresh the construction of a new tree\n");
        current_seq_no++;
        post sendNotification();
    }

    event void TimerStart.fired(){
            dbg("routing", "start the construction of a new tree\n");
            call TimerRefresh.startPeriodic(REFRESH_PERIOD);
            post sendNotification();
    }

    event void TimerReSend.fired(){
        post sendNotification();
    }

    event void TimerStopSending.fired(){
        call TimerReSend.stop();   
        dbg("routing", "Stop periodic send\n"); 
    }

    event void AMSend.sendDone(message_t* msg, error_t error)
    {
        busy = FALSE;
        if ( &pkt != msg || error != SUCCESS){
            if(TOS_NODE_ID != 0)
                call TimerReSend.startOneShot(call Random.rand16()%100);
            //dbg("routing", "messaggio mandato correttamente \n");
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        if (len == sizeof(TreeBuilding) && TOS_NODE_ID != 0 ){
            TreeBuilding* treemsg = (TreeBuilding*) payload;
            //dbg("routing", "COST\t%u\tSOURCE\t%u\tSEQR\t%u\tMSEQ\t%u\t \n", treemsg->cost,call AMPacket.source(msg), treemsg->seq_no, current_seq_no);

            if (treemsg->seq_no < current_seq_no) //Messages of an old seq, i have to re build the tree
                return msg;
            
            if (treemsg->seq_no == current_seq_no){
                if( distance == treemsg->cost ){
                    if(index_buffer < BUFFER_SIZE){
                        uint8_t i = 0;
                        bool same = FALSE;
                        parent_data temp_parent;
                        temp_parent.cost = treemsg->cost;
                        temp_parent.seq_no = treemsg->seq_no;
                        temp_parent.parent = call AMPacket.source(msg);

                        for( i = 0; i < index_buffer; i++){
                            if (parent_buffer[i].parent == temp_parent.parent){
                                same = TRUE;
                            }
                        }
                        if(!same){
                            parent_buffer[index_buffer] = temp_parent;
                            index_buffer++;
                            
                            /*
                            dbg("routing","-----------------------------------------------------------\n");
                            dbg("routing","Num of parent = %u \n",index_buffer);
                            //dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",temp_parent.cost,temp_parent.seq_no,temp_parent.parent);
                            
                            for( i = 0 ; i < index_buffer; i ++){
                                dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",parent_buffer[i].cost,parent_buffer[i].seq_no,parent_buffer[i].parent);
                            }
                            dbg("routing","-----------------------------------------------------------\n");
                            */
                            signal TreeConnection.parentUpdate(parent_buffer);
                        }
                    }
                }
                if( distance > treemsg->cost ){
                    parent_data temp_parent;
                    uint8_t i = 0;
                    //Delete all pev parent
                    for( i = 0 ; i < BUFFER_SIZE; i ++){
                        parent_buffer[i].cost = INF;
                        parent_buffer[i].seq_no = INF;
                        parent_buffer[i].parent = INF;
                    }
                    distance = treemsg->cost;
                    temp_parent.cost = treemsg->cost;
                    temp_parent.seq_no = treemsg->seq_no;
                    temp_parent.parent = call AMPacket.source(msg);
                    //dbg("routing","Beter parent found\n");
                    
                    parent_buffer[0] = temp_parent;
                    index_buffer = 1;
                    
                    /*
                    dbg("routing","Num of parent = %u \n",index_buffer);
                        //dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",temp_parent.cost,temp_parent.seq_no,temp_parent.parent);
                    
                    for( i = 0 ; i < index_buffer; i ++){
                        dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",parent_buffer[i].cost,parent_buffer[i].seq_no,parent_buffer[i].parent);
                    }
                    dbg("routing","------------------------------\n");
                    dbg("routing","Start sending periodicaly\n");
                    */
                    signal TreeConnection.parentUpdate(parent_buffer);
                    call TimerReSend.startPeriodic(call Random.rand16() % RAND_PERIOD);
                    call TimerStopSending.startOneShot(STOP_PERIOD);
                }
                //dbg("routing", "SET\tPARENT\t%u\tCOST\t%u\n", current_parent, current_cost);
            }
            
            else if (treemsg->seq_no > current_seq_no){
                uint8_t i;
                parent_data temp_parent;
                temp_parent.cost = treemsg->cost;
                temp_parent.seq_no = treemsg->seq_no;
                temp_parent.parent = call AMPacket.source(msg);
                for( i = 0 ; i < BUFFER_SIZE; i ++){
                    parent_buffer[i].cost = INF;
                    parent_buffer[i].seq_no = INF;
                    parent_buffer[i].parent = INF;
                }
                index_buffer = 0;
                distance = treemsg->cost;
                current_seq_no = treemsg->seq_no;
                
                //dbg("routing", "New tree construction reveled, seq \t%u\n",current_seq_no);

                parent_buffer[index_buffer] = temp_parent;
                index_buffer ++;
                /*
                dbg("routing","---------------------------------\n");
                dbg("routing","Num of parent = %u \n",index_buffer);
                //dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",temp_parent.cost,temp_parent.seq_no,temp_parent.parent);
                
                for( i = 0 ; i < index_buffer; i ++){
                    dbg("routing","Cost = %u\t Seq_no = %u\t Source = %u\n",parent_buffer[i].cost,parent_buffer[i].seq_no,parent_buffer[i].parent);
                }
                dbg("routing","----------------------------------\n");
                dbg("routing","Start sending periodicaly\n");
                */
                signal TreeConnection.parentUpdate(parent_buffer);
                call TimerReSend.startPeriodic(call Random.rand16() % RAND_PERIOD);
                call TimerStopSending.startOneShot(STOP_PERIOD);
            }
        }
        return msg;
    }

}
