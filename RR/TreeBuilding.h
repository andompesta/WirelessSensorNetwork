#ifndef TREEBUILDING_H
#define TREEBUILDING_H

#define BUFFER_SIZE 4
#define INF 65500
#define Q_SIZE 15
#define RAND_PERIOD 999

enum
{
  AM_TREEBUILDING = 33,
  REFRESH_PERIOD = 307200,
  START_PERIOD = 1000,
  STOP_PERIOD = 2000,
};

typedef nx_struct TreeBuilding{
	nx_uint16_t cost;
	nx_uint16_t seq_no;
} TreeBuilding;

typedef nx_struct p_data {
    nx_uint16_t parent;	//parent id
    nx_uint16_t seq_no;	
    nx_uint16_t cost;	//cost of the root to the sink
} parent_data;


#endif
