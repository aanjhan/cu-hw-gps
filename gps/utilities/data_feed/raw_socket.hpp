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
    
    //static void ListDevices(std::vector<std::string> &deviceList) throw(IOException) = 0;
    //static void GetMACAddress(const std::string &deviceName, uint8_t *address) throw(IOException) = 0;
    
    virtual void Open(const std::string &deviceName="") throw(IOException,
                                                              SocketStateException) = 0;
    virtual void Close() = 0;
    virtual bool IsOpen() = 0;

    virtual void GetMACAddress(uint8_t *address) throw(IOException) = 0;

    virtual void Write(const void *buffer, size_t length) throw(SocketStateException) = 0;
    virtual void Write(const uint8_t *dest, const void *buffer, size_t length) throw(SocketStateException) = 0;
};

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
