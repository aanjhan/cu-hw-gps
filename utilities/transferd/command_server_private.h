#ifndef COMMAND_SERVER_PRIVATE_H
#define COMMAND_SERVER_PRIVATE_H

#include <stdint.h>
#include <stdio.h>

typedef struct basic_PendingCommand
{
    uint16_t type;
    uint16_t transferID;
    uint16_t options;
    void* frame;
} PendingCommand;

typedef struct basic_PendingPutFrame
{
    uint32_t totalSize;
    uint32_t receivedBytes;
    char* path;
    FILE* file;
} PendingPutFrame;

int Command_Execute_Put(void);

int Command_Compare(void* a, void* b);
void Command_Dealloc(void* a);

#endif
