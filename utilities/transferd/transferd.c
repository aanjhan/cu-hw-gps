#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include "socket.h"
#include "command_server.h"

Socket listenSock, acceptSock;

void interrupt(int signal)
{
    Socket_Close(&acceptSock);
    Socket_Close(&listenSock);
    printf("Socket closed.\n");
    exit(0);
}

int main(int argc, char* argv[])
{
    struct sigaction action;

    action.sa_handler=interrupt;
    action.sa_flags=0;
    sigemptyset(&action.sa_mask);
    if(sigaction(SIGINT,&action,NULL)==-1 ||
       sigaction(SIGTERM,&action,NULL)==-1)
    {
        printf("Unable to trap signal.\n");
        return 1;
    }

    Socket_Init(&listenSock);
    Socket_Init(&acceptSock);

    if(Socket_Listen(&listenSock,"4000")<1)
    {
        printf("Unable to open socket.\n");
        return 1;
    }
    else printf("Listening...\n");

    while(1)
    {
//        inet_ntop(incomingAddr.ss_family,
//                  &(((struct sockaddr_in*)&incomingAddr)->sin_addr),
//                  str,sizeof(str));
//                  printf("Incoming connection from %s.\n",str);
        if(Socket_Update(&listenSock)==SOCKET_EVENT_CONNECT)
        {
            if(Socket_Accept(&listenSock,&acceptSock)!=1)
            {
                printf("Error accepting connection.\n");
                continue;
            }
            else printf("Client connected.\n");
        }

        switch(Socket_Update(&acceptSock))
        {
        case SOCKET_EVENT_READ:
            Command_Execute(&acceptSock);
            break;
        case SOCKET_EVENT_CLOSE:
            //FIXME Need server not to close the connection until
            //FIXME the client disconnects. Otherwise, the server
            //FIXME will only get a single frame, even if the client
            //FIXME sends multiple.
            printf("Connection closed.\n");
            break;
        default: break;
        }
    }
    
    return 0;
}
