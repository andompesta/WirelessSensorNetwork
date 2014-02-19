#include "DataMsg.h"
#include "TreeBuilding.h"

configuration DataCollectionC
{
}
implementation
{
    components DataCollectionP;
    //includo il componente TreeRoutingC xkè così quando faccio il boot di questo progetto parte anche quello,
    //xkè è bindato al boot
    components MainC, TreeRoutingC, ActiveMessageC;
    components new TimerMilliC() as Timer1;
    components new TimerMilliC() as Timer2;
    components new AMSenderC(AM_DATAMSG);
    components new AMReceiverC(AM_DATAMSG);
    components RandomC;
    components new QueueC(DataMsg,Q_SIZE) as Queue0;
	components new QueueC(DataMsg,Q_SIZE) as Queue1;

    DataCollectionP.Boot -> MainC.Boot;
    DataCollectionP.TimerSend -> Timer1;
    DataCollectionP.SendInterval -> Timer2;
    DataCollectionP.Packet -> AMSenderC;
    DataCollectionP.AMPacket -> ActiveMessageC;
    DataCollectionP.AMSend -> AMSenderC;
    DataCollectionP.AMControl -> ActiveMessageC;
    DataCollectionP.Receive -> AMReceiverC;
    DataCollectionP.Queue -> Queue0;
    DataCollectionP.QueueSend -> Queue1;
    DataCollectionP.Random -> RandomC;
    DataCollectionP.TreeConnection -> TreeRoutingC;
    
}

