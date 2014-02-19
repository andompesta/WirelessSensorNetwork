#ifndef DATAMSG_H
#define DATAMSG_H

enum
{
  AM_DATAMSG = 22,
  R_R_PERIOD = 5072,
};

typedef nx_struct DataMsg
{
  	nx_uint16_t source;
  	nx_uint16_t address;
}DataMsg;

typedef nx_struct SentToParent
{
  	nx_uint16_t parent;
  	nx_uint16_t num_msg_send;
}num_msg;

#endif
