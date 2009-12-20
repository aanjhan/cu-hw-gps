#ifndef SOCKET_H
#define SOCKET_H

typedef enum { TCP, UDP } TransportProtocol;
typedef enum
{
    LISTENING,
    CONNECTED,
    DISCONNECTED
} SocketState;

struct basic_Socket
{
    int socket;
    TransportProtocol protocol;
    SocketState state;

    void (*connectDelegate)();
    void (*readDelegate)();
    void (*closeDelegate)();
};
typedef struct basic_Socket Socket;

#define SOCKET_EVENT_NONE    0
#define SOCKET_EVENT_CONNECT 1
#define SOCKET_EVENT_CLOSE   2
#define SOCKET_EVENT_READ    3

void Socket_Init(Socket* sock);
int Socket_IsOpen(Socket* sock);
void Socket_Close(Socket* sock);

int Socket_Listen(Socket* sock, char* port);
int Socket_Connect(Socket* sock, char* address, char* port);
int Socket_Update(Socket* sock);
int Socket_Accept(Socket* listenSocket, Socket* acceptSocket);

int Socket_Read(Socket* sock, char* buffer, int length);
int Socket_Write(Socket* sock, char* buffer, int length);

#endif
