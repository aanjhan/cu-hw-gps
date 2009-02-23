#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include "command_server.h"
#include "command_server_private.h"
#include "command_private.h"
#include "list.h"

#define SAFE_FREE(x) if(x!=NULL)free(NULL)

char cmdBuffer[CMD_MAX_FRAME_SIZE];
List* pendingCommands=NULL;

void Command_Execute(Socket* sock)
{
    Command* command;
    int bytesRead;

    //Is there data to read on the socket?
    if(sock==NULL)return;
    if(Socket_Update(sock)!=SOCKET_EVENT_READ)return;

    //Read the command header.
    bytesRead=Socket_Read(sock,cmdBuffer,sizeof(Command));
    command=(Command*)cmdBuffer;

    //Convert byte ordering.
    command->type=ntohs(command->type);
    command->transferID=ntohs(command->transferID);
    command->options=ntohs(command->options);
    command->length=ntohl(command->length);

    //Read the frame and payload.
    bytesRead+=Socket_Read(sock,cmdBuffer+sizeof(Command),command->length-sizeof(Command));
    
    if(bytesRead==0 || bytesRead!=command->length)return;

    switch(command->type)
    {
    case CMD_PUT:
        Command_Execute_Put();
        break;
    default: break;
    }
}

int Command_Execute_Put(void)
{
    Command* command=(Command*)cmdBuffer;
    PutFrame* frame=(PutFrame*)(cmdBuffer+sizeof(Command));
    char* path=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));
    char* payload=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));
    List* pendingEntry;
    PendingCommand* pendingCommand;
    PendingPutFrame* pendingFrame;
    
    //Convert byte ordering.
    frame->totalSize=ntohl(frame->totalSize);
    frame->pathLength=ntohs(frame->pathLength);
    frame->segment=ntohs(frame->segment);
    frame->segmentLength=ntohl(frame->segmentLength);
    frame->offset=ntohl(frame->offset);

    printf("Frame: type=PUT, segment=%d, offset=%d, length=%d\n",
           frame->segment,
           frame->offset,
           frame->segmentLength);

    //Is this command already pending?
    if((pendingEntry=List_Search(pendingCommands,command,Command_Compare))==NULL)
    {
        //Allocate a new pending command entry.
        pendingCommand=(PendingCommand*)malloc(sizeof(PendingCommand));
        if(pendingCommand==NULL)return -1;
        pendingCommand->frame=malloc(sizeof(PendingPutFrame));
        if(pendingCommand->frame==NULL)
        {
            free(pendingCommand);
            return -1;
        }
        pendingFrame=(PendingPutFrame*)pendingCommand->frame;

        //Add entry to pending command list.
        pendingEntry=List_Insert(&pendingCommands,pendingCommand);

        //Initialize entry.
        pendingCommand->type=command->type;
        pendingCommand->transferID=command->transferID;
        pendingCommand->options=command->options;
        pendingFrame->totalSize=frame->totalSize;
        pendingFrame->receivedBytes=0;

        //Set command path and update payload.
        pendingFrame->path=(char*)malloc((frame->pathLength+1)*sizeof(char));
        strncpy(pendingFrame->path,path,frame->pathLength);
        pendingFrame->path[frame->pathLength]='\0';
        payload+=frame->pathLength;

        //Open specified file.
        pendingFrame->file=fopen(pendingFrame->path,"w");
        if(pendingFrame->file==NULL)return -2;
    }
    else
    {
        pendingCommand=(PendingCommand*)pendingEntry->contents;
        pendingFrame=(PendingPutFrame*)pendingCommand->frame;
    }

    //Write data to file at specified offset.
    fseek(pendingFrame->file,frame->offset,SEEK_SET);
    fwrite(payload,sizeof(char),frame->segmentLength,pendingFrame->file);
    pendingFrame->receivedBytes+=frame->segmentLength;

    //Is this command complete?
    if(pendingFrame->receivedBytes==pendingFrame->totalSize)
    {
        printf("PUT size=%dB, file='%s'\n",pendingFrame->totalSize,pendingFrame->path);
        pendingCommands=List_Remove(pendingCommands,pendingEntry,Command_Dealloc);
    }
    
    return 0;
}

int Command_Compare(void* a, void* b)
{
    return ((PendingCommand*)a)->transferID-((Command*)b)->transferID;
}

void Command_Dealloc(void* a)
{
    PendingCommand* cmd=(PendingCommand*)a;
    if(cmd==NULL)return;

    if(cmd->frame!=NULL)
    {
        switch(cmd->type)
        {
        case CMD_PUT:
            if(((PendingPutFrame*)cmd->frame)->file!=NULL)
            {
                fclose(((PendingPutFrame*)cmd->frame)->file);
            }
            SAFE_FREE(((PendingPutFrame*)cmd->frame)->path);
            break;
        default: break;
        }
    
        SAFE_FREE(cmd->frame);
    }
    free(cmd);
}
