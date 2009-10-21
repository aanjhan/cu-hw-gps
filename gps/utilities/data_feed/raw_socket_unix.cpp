#include "raw_socket_unix.hpp"
#include <pcap.h>
#include <sys/ioctl.h>
#include <net/if.h>

using namespace std;

RawSocketUnix::RawSocketUnix()
{
    deviceName="";
    device=NULL;
}

RawSocketUnix::~RawSocketUnix()
{
    Close();
}

void RawSocketUnix::ListDevices(std::vector<std::string> &deviceList) throw(IOException)
{
    pcap_if_t *devList, *dev;
    char errbuf[PCAP_ERRBUF_SIZE];
            
    if(pcap_findalldevs(&devList,errbuf)==-1)
    {
        throw IOException(errbuf);
    }

    deviceList.clear();
    for(dev=devList;dev!=NULL;dev=dev->next)
    {
        deviceList.push_back(dev->name);
    }

    pcap_freealldevs(devList);
}

void RawSocketUnix::GetMACAddress(const std::string &deviceName, uint8_t *address) throw(IOException)
{
    int sock;
    struct ifreq ifr;
    
    if(deviceName=="")throw IOException("no device specified");

    //Create socket for ioctl.
    if((sock=socket(PF_INET,SOCK_DGRAM,0))<0)
    {
        //FIXME Look at errno (see socket(2)) and throw appropriate exception.
        throw IOException("unable to create socket");
    }

    //Setup interface config structure.
    memset(&ifr,0,sizeof(ifr));
    strncpy(ifr.ifr_ifrn.ifrn_name,deviceName.c_str(),IFNAMSIZ);

    //Get hardware address.
    if(ioctl(sock,SIOCGIFHWADDR,&ifr)==-1)
    {
        close(sock);
        throw IOException("unable to retrieve interface configuration");
    }
    else close(sock);

    memcpy(address,ifr.ifr_ifru.ifru_hwaddr.sa_data,6);
}

void RawSocketUnix::Open(const std::string &deviceName) throw(IOException,
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

void RawSocketUnix::Close()
{
    if(IsOpen())
    {
        pcap_close(device);
        device=NULL;
    }
}

void RawSocketUnix::GetMACAddress(uint8_t *address) throw(IOException)
{
    if(deviceName=="")throw IOException("no device specified");

    memcpy(address,macAddress,6);
}

void RawSocketUnix::Write(const void *buffer, size_t length) throw(SocketStateException)
{
    uint8_t dest[6]={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};

    Write(dest,buffer,length);
}

void RawSocketUnix::Write(const uint8_t *dest, const void *buffer, size_t length) throw(SocketStateException)
{
    uint8_t writeBuffer[RAW_SOCKET_BUFFER_LEN];
    
    if(!IsOpen())throw SocketStateException("socket not open");

    //Limit data to MTU length.
    if(length>RAW_SOCKET_MTU)length=RAW_SOCKET_MTU;
    
    memcpy(writeBuffer,dest,6);
    memcpy(writeBuffer+6,macAddress,6);
    writeBuffer[12]=0x12;
    writeBuffer[13]=0x34;
    memcpy(writeBuffer+14,buffer,length);
    //FIXME Insert CRC if enabled?
    
    //FIXME Error check for socket closing?
    pcap_inject(device,writeBuffer,14+length);
}
