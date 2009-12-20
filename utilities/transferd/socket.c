#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
#include "socket.h"

void Socket_Init(Socket* sock)
{
    if(sock==NULL)return;
    
    sock->socket=-1;
    sock->protocol=TCP;
    sock->state=DISCONNECTED;
    sock->connectDelegate=NULL;
    sock->readDelegate=NULL;
    sock->closeDelegate=NULL;
}

int Socket_IsOpen(Socket* sock)
{
    return sock!=NULL && sock->state!=DISCONNECTED;
}

void Socket_Close(Socket* sock)
{
    if(sock==NULL)return;

    if(sock->socket!=-1)
    {
        close(sock->socket);
        sock->socket=-1;
        sock->state=DISCONNECTED;
    }
}

int Socket_Listen(Socket* sock, char* port)
{
    struct addrinfo hints;
    struct addrinfo *info, *itr;
    int tempSock=-1;
    
    if(sock==NULL || port==NULL)return -1;
    else if(sock->state!=DISCONNECTED)return -2;

    memset(&hints,0,sizeof(struct addrinfo));
    hints.ai_family=AF_INET;
    hints.ai_flags=AI_PASSIVE;

    switch(sock->protocol)
    {
    case UDP:
        hints.ai_socktype=SOCK_DGRAM;
        break;
    case TCP:
        hints.ai_socktype=SOCK_STREAM;
        break;
    default: return -1;
    }

    if(getaddrinfo(NULL,port,&hints,&info)!=0)
    {
        return -3;
    }

    for(itr=info;itr!=NULL;itr=itr->ai_next)
    {
        int yes=1;
        
        if((tempSock=socket(itr->ai_family,itr->ai_socktype,itr->ai_protocol))==-1)
        {
            continue;
        }

        setsockopt(tempSock,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof(int));
        
        if(bind(tempSock,itr->ai_addr,itr->ai_addrlen)!=0)
        {
            close(tempSock);
            continue;
        }
        else break;
    }

    freeaddrinfo(info);

    if(itr==NULL)
    {
        return -3;
    }
    else if(listen(tempSock,10)==-1)
    {
        close(tempSock);
        return -4;
    }

    sock->socket=tempSock;
    sock->state=LISTENING;
    return 1;
}

int Socket_Connect(Socket* sock, char* address, char* port)
{
    struct addrinfo hints;
    struct addrinfo *info, *itr;
    int tempSock=-1;
    
    if(sock==NULL || address==NULL || port==NULL)return -1;
    else if(sock->state!=DISCONNECTED)return -2;

    memset(&hints,0,sizeof(struct addrinfo));
    hints.ai_family=AF_INET;

    switch(sock->protocol)
    {
    case UDP:
        hints.ai_socktype=SOCK_DGRAM;
        break;
    case TCP:
        hints.ai_socktype=SOCK_STREAM;
        break;
    default: return -1;
    }

    if(getaddrinfo(address,port,&hints,&info)!=0)
    {
        return -3;
    }

    for(itr=info;itr!=NULL;itr=itr->ai_next)
    {
        if((tempSock=socket(itr->ai_family,itr->ai_socktype,itr->ai_protocol))==-1)
        {
            continue;
        }
        else if(connect(tempSock,itr->ai_addr,itr->ai_addrlen)==-1)
        {
            close(tempSock);
            continue;
        }
        else break;
    }

    freeaddrinfo(info);

    if(itr==NULL)
    {
        return -3;
    }

    sock->socket=tempSock;
    sock->state=CONNECTED;
    return 1;
}

int Socket_Update(Socket* sock)
{
    fd_set fds;
    struct timeval timeout;
    char buffer;
    
    if(sock==NULL || sock->socket==-1)return SOCKET_EVENT_NONE;

    FD_ZERO(&fds);
    FD_SET(sock->socket,&fds);
    timeout.tv_sec=0;
    timeout.tv_usec=0;

    if(select(sock->socket+1,&fds,NULL,NULL,&timeout)<=0)
    {
        return SOCKET_EVENT_NONE;
    }

    switch(sock->state)
    {
    case LISTENING:
        if(sock->connectDelegate!=NULL)sock->connectDelegate();
        return SOCKET_EVENT_CONNECT;
    case CONNECTED:
        if(recv(sock->socket,&buffer,1,MSG_PEEK)<=0)
        {
            Socket_Close(sock);
            if(sock->closeDelegate!=NULL)sock->closeDelegate();
            return SOCKET_EVENT_CLOSE;
        }
        else
        {
            if(sock->readDelegate!=NULL)sock->readDelegate();
            return SOCKET_EVENT_READ;
        }
        break;
    default: return SOCKET_EVENT_NONE;
    }
}

int Socket_Accept(Socket* listenSocket, Socket* acceptSocket)
{
    struct sockaddr_storage incomingAddr;
    socklen_t incomingSize;

    if(listenSocket==NULL || acceptSocket==NULL)return -1;
    else if(listenSocket->socket==-1)return -2;
    else if(acceptSocket->socket!=-1)return -3;

    acceptSocket->protocol=listenSocket->protocol;

    incomingSize=sizeof(struct sockaddr_storage);
    acceptSocket->socket=accept(listenSocket->socket,
                                (struct sockaddr*)&incomingAddr,
                                &incomingSize);
    if(acceptSocket->socket==-1)
    {
        return -4;
    }
    else acceptSocket->state=CONNECTED;

    return 1;
}

int Socket_Read(Socket* sock, char* buffer, int length)
{
    if(sock==NULL || buffer==NULL)return -1;
    else if(sock->state==DISCONNECTED)return -2;

    return recv(sock->socket,buffer,length,0);
}

int Socket_Write(Socket* sock, char* buffer, int length)
{
    int totalSent=0, bytesSent;
    if(sock==NULL || buffer==NULL)return -1;
    else if(sock->state==DISCONNECTED)return -2;

    while(totalSent<length)
    {
        bytesSent=send(sock->socket,buffer,length-totalSent,0);
        if(bytesSent==-1)return -1;
        totalSent+=bytesSent;
        buffer+=bytesSent;
    }
    
    return totalSent;
}
