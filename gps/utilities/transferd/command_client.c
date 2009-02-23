#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/stat.h>
#include "command_client.h"
#include "command_private.h"

#define MIN(a,b) (a<b ? a : b)

char cmdBuffer[CMD_MAX_FRAME_SIZE];
int nextTransferID=0;

int Command_Put(Socket* socket, char* path, char* data, int length)
{
    int numFrames, totalSize;
    int dataOffset, cmdLength, segmentLength;
    Command* cmd;
    PutFrame* frame;
    char *payload;

    if(socket==NULL || path==NULL || data==NULL ||
       !Socket_IsOpen(socket))
    {
        return -1;
    }

    //Number of frames required.
    numFrames=(int)(((float)length)/CMD_SEGMENT_SIZE(PutFrame))+1;

    //Total transmission size (in bytes).
    totalSize=length+numFrames*CMD_FRAME_OVERHEAD(PutFrame);

    //Setup buffer pointers.
    cmd=(Command*)cmdBuffer;
    frame=(PutFrame*)(cmdBuffer+sizeof(Command));
    payload=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));

    //Setup command/frame headers.
    cmd->type=CMD_PUT;
    cmd->transferID=nextTransferID++;
    cmd->options=0;
    cmd->length=CMD_FRAME_OVERHEAD(PutFrame);
    frame->totalSize=length;
    frame->offset=0;

    //Put commands always begin with a path setup
    //frame. If the data is small enough to fit
    //into a single frame with the path, it is sent
    //immediately following the path. Otherwise, no
    //data is included in the setup frame.
    frame->pathLength=strlen(path);
    memcpy(payload,path,frame->pathLength);
    payload+=frame->pathLength;
    cmd->length+=frame->pathLength;
    
    frame->segment=0;
    if((CMD_SEGMENT_SIZE(PutFrame)-frame->pathLength)>=length)
    {
        frame->segmentLength=length;
        memcpy(payload,data,length);
        cmd->length+=length;
        dataOffset=length;
    }
    else
    {
        frame->segmentLength=0;
        dataOffset=0;
        numFrames++;
    }

    //Store pre-reordered command length.
    cmdLength=cmd->length;

    //Convert to network byte order.
    cmd->type=htons(cmd->type);
    cmd->transferID=htons(cmd->transferID);
    cmd->options=htons(cmd->options);
    cmd->length=htonl(cmd->length);
    frame->totalSize=htonl(frame->totalSize);
    frame->pathLength=htons(frame->pathLength);
    frame->segmentLength=htonl(frame->segmentLength);
    frame->offset=htonl(frame->offset);

    //Send setup frame.
    Socket_Write(socket,cmdBuffer,cmdLength);

    frame->pathLength=0;
    payload=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));
    while(dataOffset<length)
    {
        //Update segment ID, segment length, and command length.
        if(dataOffset!=0)
        {
            frame->segment=ntohs(frame->segment);
            frame->segment++;
            frame->segment=htons(frame->segment);
        }
        frame->segmentLength=MIN(length-dataOffset,CMD_SEGMENT_SIZE(PutFrame));
        frame->offset=dataOffset;
        cmd->length=CMD_FRAME_OVERHEAD(PutFrame)+frame->segmentLength;
        segmentLength=frame->segmentLength;
        cmdLength=cmd->length;
        memcpy(payload,data+dataOffset,frame->segmentLength);

        //Convert byte ordering.
        frame->segmentLength=htonl(frame->segmentLength);
        cmd->length=htonl(cmd->length);
        frame->offset=htonl(frame->offset);

        //Send frame.
        //FIXME What if this function fails?
        //FIXME What if the connection is lost/closed?
        Socket_Write(socket,cmdBuffer,cmdLength);

        //Update data offset.
        dataOffset+=segmentLength;
    }
    
    return numFrames;
}

int Command_PutFile(Socket* socket, char* path, char* fileName)
{
    int numFrames, totalSize, length;
    int dataOffset, cmdLength, segmentLength;
    FILE* file;
    Command* cmd;
    PutFrame* frame;
    char *payload;
    struct stat fileStats;

    if(socket==NULL || path==NULL || file==NULL ||
       !Socket_IsOpen(socket))
    {
        return -1;
    }

    //Open file and get length.
    file=fopen(fileName,"r");
    if(file==NULL)return -1;
    stat(fileName,&fileStats);
    length=fileStats.st_size;

    //Number of frames required.
    numFrames=(int)(((float)length)/CMD_SEGMENT_SIZE(PutFrame))+1;

    //Total transmission size (in bytes).
    totalSize=length+numFrames*CMD_FRAME_OVERHEAD(PutFrame);

    //Setup buffer pointers.
    cmd=(Command*)cmdBuffer;
    frame=(PutFrame*)(cmdBuffer+sizeof(Command));
    payload=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));

    //Setup command/frame headers.
    cmd->type=CMD_PUT;
    cmd->transferID=nextTransferID++;
    cmd->options=0;
    cmd->length=CMD_FRAME_OVERHEAD(PutFrame);
    frame->totalSize=length;
    frame->offset=0;

    //Put commands always begin with a path setup
    //frame. If the data is small enough to fit
    //into a single frame with the path, it is sent
    //immediately following the path. Otherwise, no
    //data is included in the setup frame.
    frame->pathLength=strlen(path);
    memcpy(payload,path,frame->pathLength);
    payload+=frame->pathLength;
    cmd->length+=frame->pathLength;
    
    frame->segment=0;
    if((CMD_SEGMENT_SIZE(PutFrame)-frame->pathLength)>=length)
    {
        frame->segmentLength=length;
        fread(payload,sizeof(char),length,file);
        cmd->length+=length;
        dataOffset=length;
    }
    else
    {
        frame->segmentLength=0;
        dataOffset=0;
        numFrames++;
    }

    //Store pre-reordered command length.
    cmdLength=cmd->length;

    //Convert to network byte order.
    cmd->type=htons(cmd->type);
    cmd->transferID=htons(cmd->transferID);
    cmd->options=htons(cmd->options);
    cmd->length=htonl(cmd->length);
    frame->totalSize=htonl(frame->totalSize);
    frame->pathLength=htons(frame->pathLength);
    frame->segmentLength=htonl(frame->segmentLength);
    frame->offset=htonl(frame->offset);

    //Send setup frame.
    Socket_Write(socket,cmdBuffer,cmdLength);

    frame->pathLength=0;
    payload=(cmdBuffer+CMD_FRAME_OVERHEAD(PutFrame));
    while(dataOffset<length)
    {
        //Update segment ID, segment length, and command length.
        if(dataOffset!=0)
        {
            frame->segment=ntohs(frame->segment);
            frame->segment++;
            frame->segment=htons(frame->segment);
        }
        frame->segmentLength=MIN(length-dataOffset,CMD_SEGMENT_SIZE(PutFrame));
        frame->offset=dataOffset;
        cmd->length=CMD_FRAME_OVERHEAD(PutFrame)+frame->segmentLength;
        segmentLength=frame->segmentLength;
        cmdLength=cmd->length;
        fread(payload,sizeof(char),frame->segmentLength,file);

        //Convert byte ordering.
        frame->segmentLength=htonl(frame->segmentLength);
        cmd->length=htonl(cmd->length);
        frame->offset=htonl(frame->offset);

        //Send frame.
        //FIXME What if this function fails?
        //FIXME What if the connection is lost/closed?
        Socket_Write(socket,cmdBuffer,cmdLength);

        //Update data offset.
        dataOffset+=segmentLength;
    }

    fclose(file);
    
    return numFrames;
}
