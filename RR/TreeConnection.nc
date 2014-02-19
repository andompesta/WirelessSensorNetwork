#include "TreeBuilding.h"
interface TreeConnection {

  /* Notifies the update of the parent or the availability of a new parent */
  event void parentUpdate(parent_data parent_b[BUFFER_SIZE]);

}
