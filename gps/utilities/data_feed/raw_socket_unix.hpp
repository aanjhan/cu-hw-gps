#ifndef RAW_SOCKET_UNIX_HPP
#define RAW_SOCKET_UNIX_HPP

#include "raw_socket.hpp"

class RawSocketUnix : public IRawSocket
{
public:
    RawSocketUnix();
    virtual ~RawSocketUnix();
    
    virtual void Open(const char *device="") throw(AccessException,
                                                   InvalidDeviceException,
                                                   SocketStateException);
    virtual void Close();

    virtual bool IsOpen(){ return socket_desc!=-1; }

    virtual void Write(const void *buffer, size_t length) throw(SocketStateException);

private:
    std::string device;
    int socket_desc;
};

#endif
