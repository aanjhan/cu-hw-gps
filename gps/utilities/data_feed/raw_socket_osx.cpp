#include "raw_socket_osx.hpp"
#include <pcap.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if_dl.h>

using namespace std;

RawSocketOSX::RawSocketOSX()
{
    deviceName="";
    device=NULL;
}

RawSocketOSX::~RawSocketOSX()
{
    Close();
}

void RawSocketOSX::ListDevices(std::vector<std::string> &deviceList) throw(IOException)
{
    struct ifaddrs *ifList;
    if(getifaddrs(&ifList)<0)
    {
        throw IOException("unable to retrieve interface information");
    }

    deviceList.clear();
    
    struct ifaddrs *ifaddr;
    for(ifaddr=ifList;ifaddr!=NULL;ifaddr=ifaddr->ifa_next)
    {
        //Is this interface in the list?
        if(find(deviceList.begin(),deviceList.end(),ifaddr->ifa_name)==deviceList.end())
        {
            deviceList.push_back(ifaddr->ifa_name);
        }
    }
    freeifaddrs(ifList);
}

void RawSocketOSX::GetMACAddress(const std::string &deviceName, uint8_t *address) throw(IOException)
{
    if(deviceName=="")throw IOException("no device specified");

    struct ifaddrs *ifList;
    if(getifaddrs(&ifList)<0)
    {
        throw IOException("unable to retrieve interface information");
    }
    
    struct ifaddrs *ifaddr;
    for(ifaddr=ifList;ifaddr!=NULL;ifaddr=ifaddr->ifa_next)
    {
        //Is this the specified device?
        if(deviceName!=ifaddr->ifa_name)continue;

        //Is there an address in this record?
        if(ifaddr->ifa_addr==NULL)continue;

        //Is this a hardware address?
        if(ifaddr->ifa_addr->sa_family==AF_LINK)
        {
            struct sockaddr_dl *dladdr=(struct sockaddr_dl *)ifaddr->ifa_addr;//FIXME Check this.
            memcpy(address,LLADDR(dladdr),6);
            break;
        }
    }
    freeifaddrs(ifList);

    //No address found.
    if(ifaddr==NULL)
    {
        throw IOException("device not found");
    }
}

void RawSocketOSX::Open(const std::string &deviceName) throw(IOException,
                                                             SocketStateException)
{
    char errbuf[PCAP_ERRBUF_SIZE];
    
    if(IsOpen())throw SocketStateException("socket already open");
    
    if(deviceName!="")this->deviceName=deviceName;

    //Get device hardware address.
    GetMACAddress(deviceName,macAddress);

    //Create socket.
    if((device=pcap_open_live(deviceName.c_str(),100,1,100,errbuf))==NULL)
    {
        throw IOException(errbuf);
    }
}

void RawSocketOSX::Close()
{
    if(IsOpen())
    {
        pcap_close(device);
        device=NULL;
    }
}

void RawSocketOSX::GetMACAddress(uint8_t *address) throw(IOException)
{
    if(deviceName=="")throw IOException("no device specified");

    memcpy(address,macAddress,6);
}

void RawSocketOSX::Write(const void *buffer, size_t length) throw(SocketStateException)
{
    uint8_t dest[6]={0x01,0x02,0x03,0x04,0x05,0x06};

    Write(dest,buffer,length);
}

void RawSocketOSX::Write(const uint8_t *dest, const void *buffer, size_t length) throw(SocketStateException)
{
    uint8_t writeBuffer[RAW_SOCKET_BUFFER_LEN];
    
    if(!IsOpen())throw SocketStateException("socket not open");

    //Limit data to MTU length.
    if(length>RAW_SOCKET_MTU)length=RAW_SOCKET_MTU;
    
    memcpy(writeBuffer,dest,6);
    memcpy(writeBuffer+6,macAddress,6);
    writeBuffer[12]=0x00;
    writeBuffer[13]=0x00;
    memcpy(writeBuffer+14,buffer,length);
    //FIXME Insert CRC if enabled?
    
    //FIXME Error check for socket closing?
    pcap_inject(device,writeBuffer,14+length);
}
