#ifndef RAW_SOCKET_HPP
#define RAW_SOCKET_HPP

#include <sys/types.h>
#include <vector>
#include <string>
#include "socket_exceptions.hpp"

#define RAW_SOCKET_MTU 1500
#define RAW_SOCKET_BUFFER_LEN (14+RAW_SOCKET_MTU+4)

class IRawSocket
{
public:
    virtual ~IRawSocket(){}

    /*static virtual void ListDevices(std::vector<std::string> &deviceList)  throw(AccessException,
                                                                                 InvalidDeviceException,
                                                                                 SocketStateException) = 0;
    
    virtual void Open(const char *device="") throw(AccessException,
                                                   InvalidDeviceException,
                                                   SocketStateException) = 0;
    virtual void Open(const std::string &device) throw(AccessException,
                                                       InvalidDeviceException,
                                                       SocketStateException)
    {
        Open(device.c_str());
    }
    virtual void Close() = 0;
    
    virtual bool IsOpen() = 0;

    virtual void Write(const void *buffer, size_t length) throw(SocketStateException) = 0;*/
};

//FIXME What is the macro to check Windows vs. Unix?
#if defined(WIN32)
  #include "raw_socket_win.hpp"
  #define RawSocket RawSocketWin
#elif defined(__APPLE__)
  #include "raw_socket_osx.hpp"
  #define RawSocket RawSocketOSX
#else
  #include "raw_socket_unix.hpp"
  #define RawSocket RawSocketUnix
#endif

#endif
