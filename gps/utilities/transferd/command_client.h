#ifndef COMMAND_CLIENT_H
#define COMMAND__CLIENTH

#include <stdint.h>
#include "socket.h"

int Command_Put(Socket* socket, char* path, char* data, int length);
int Command_PutFile(Socket* socket, char* path, char* fileName);

#endif
