#ifndef COMMAND_PRIVATE_H
#define COMMAND_PRIVATE_H

#include <stdint.h>

#define CMD_MAX_FRAME_SIZE 500

#define CMD_FRAME_OVERHEAD(x) (sizeof(Command)+sizeof(x))
#define CMD_SEGMENT_SIZE(x) (CMD_MAX_FRAME_SIZE-CMD_FRAME_OVERHEAD(x))

typedef struct basic_Command
{
    uint16_t type;
    uint16_t transferID;
    uint16_t options;
    uint32_t length;
    
} Command;

//Commands
#define CMD_PUT 1
#define CMD_GET 2
#define CMD_KILL 3

typedef struct basic_PutFrame
{
    uint32_t totalSize;
    uint16_t pathLength;
    
    uint16_t segment;
    uint32_t segmentLength;
    uint32_t offset;
} PutFrame;

#endif
