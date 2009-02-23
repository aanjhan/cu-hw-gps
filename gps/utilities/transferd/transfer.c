#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "socket.h"
#include "command_client.h"

int main(int argc, char* argv[])
{
    Socket sock;
    int ret;

    Socket_Init(&sock);

    printf("Connecting to %s...\n",argv[1]);
    if((ret=Socket_Connect(&sock,argv[1],"4000"))<1)
    {
        printf("Unable to connect. Error %d.\n",ret);
        return 1;
    }
    else printf("Connected...\n");

    if((ret=Command_PutFile(&sock,argv[3],argv[2]))<0)
    {
        printf("Write error %d.\n",ret);
        perror("write");
    }
    else printf("Sent %d frames.\n",ret);

    sleep(3);

    Socket_Close(&sock);
    printf("Socket closed.\n");

    return 0;
}
