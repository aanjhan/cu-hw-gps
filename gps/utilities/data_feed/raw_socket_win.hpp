#ifndef RAW_SOCKET_WIN_HPP
#define RAW_SOCKET_WIN_HPP

#include <stdint.h>
#include <pcap.h>
#include "raw_socket.hpp"

class RawSocketWin : public IRawSocket
{
public:
    RawSocketWin();
    virtual ~RawSocketWin();
    
    static void ListDevices(std::vector<std::string> &deviceList) throw(IOException);
    static void GetMACAddress(const std::string &deviceName, uint8_t *address) throw(IOException);
    
    virtual void Open(const std::string &deviceName="") throw(IOException,
                                                              SocketStateException);
    virtual void Close();
    virtual bool IsOpen(){ return device!=NULL; }

    virtual void GetMACAddress(uint8_t *address) throw(IOException);

    virtual void Write(const void *buffer, size_t length) throw(SocketStateException);
    virtual void Write(const uint8_t *dest, const void *buffer, size_t length) throw(SocketStateException);

private:
    uint8_t macAddress[6];
    std::string deviceName;
    pcap_t *device;
};

#endif
