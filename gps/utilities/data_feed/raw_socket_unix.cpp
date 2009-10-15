#include "raw_socket_unix.hpp"
#include <pcap.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if_dl.h>

//#include <sys/ioctl.h>
//#include <net/if.h>//FIXME If needed, must be before ifaddrs.h

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
    /*int sock;
    struct ifconf ifc;
    struct ifreq ifr[10];*/
    
    if(deviceName=="")throw IOException("no device specified");

    struct ifaddrs *ifList;
    if(getifaddrs(&ifList)<0)
    {
        //FIXME Look at errno (see socket(2)) and throw appropriate exception.
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

    /*//Create socket for ioctl.
    if((sock=socket(PF_INET,SOCK_DGRAM,0))<0)
    {
        //FIXME Look at errno (see socket(2)) and throw appropriate exception.
        throw IOException("unable to create socket");
    }

    //Setup interface config structure.
    memset(&ifc,0,sizeof(ifc));
    ifc.ifc_buf=ifr;
    ifc.ifc_len=sizeof(ifr);

    //Get hardware address.
    if(ioctl(sock,SIOCGIFCONF,&ifc)==-1)
    {
        close(sock);
        throw IOException("unable to retrieve interface configuration");
    }
    else close(sock);

    int numInterfaces=ifc.ifc_len/sizeof(struct ifreq);
    for(int i=0;i<numInterfaces;i++)
    {
    }

    memcpy(address,ifr.ifr_addr.sa_data,6);*/
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
    if(!IsOpen())throw SocketStateException("socket not open");

    //FIXME Error check for socket closing?
    pcap_inject(device,buffer,length);
}
