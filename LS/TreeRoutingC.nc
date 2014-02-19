#include "TreeBuilding.h"

configuration TreeRoutingC
{
  provides interface TreeConnection;
}
implementation
{
  components MainC, TreeRoutingP, ActiveMessageC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;
  components new AMSenderC(AM_TREEBUILDING);
  components new AMReceiverC(AM_TREEBUILDING);
  components RandomC;

  TreeConnection = TreeRoutingP;

  TreeRoutingP -> MainC.Boot;
  TreeRoutingP.TimerReSend -> Timer0;
  TreeRoutingP.TimerRefresh -> Timer1;
  TreeRoutingP.TimerStart -> Timer2;
  TreeRoutingP.TimerStopSending -> Timer3;
  TreeRoutingP.Packet -> AMSenderC;
  TreeRoutingP.AMPacket -> ActiveMessageC;
  TreeRoutingP.AMSend -> AMSenderC;
  TreeRoutingP.AMControl -> ActiveMessageC;
  TreeRoutingP.Receive -> AMReceiverC;
  TreeRoutingP.Random -> RandomC;
}

