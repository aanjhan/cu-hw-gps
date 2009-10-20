#include "raw_socket_win.hpp"
#include <pcap.h>
#include <windows.h>
#include <iphlpapi.h>

using namespace std;

RawSocketWin::RawSocketWin()
{
    deviceName="";
    device=NULL;
}

RawSocketWin::~RawSocketWin()
{
    Close();
}

void RawSocketWin::ListDevices(std::vector<std::string> &deviceList) throw(IOException)
{
    pcap_if_t *ifList;
    char errbuf[PCAP_ERRBUF_SIZE];

    //Find available devices.
    if(pcap_findalldevs(&ifList, errbuf)<0)
    {
        throw IOException("unable to retrieve interface information");
    }

    deviceList.clear();
    
    //Add devices to list.
    for(pcap_if_t *d=ifList; d; d=d->next)
    {
        //Is this interface in the list?
        if(find(deviceList.begin(),deviceList.end(),d->name)==deviceList.end())
        {
            deviceList.push_back(d->name);
        }
    }
    
    pcap_freealldevs(ifList);
}

void RawSocketWin::GetMACAddress(const std::string &deviceName, uint8_t *address) throw(IOException)
{
    if(deviceName=="")throw IOException("no device specified");
    
    IP_ADAPTER_INFO ifList[16];
    DWORD dwBufLen = sizeof(ifList);

    //Get device information.
    if(GetAdaptersInfo(ifList,&dwBufLen)!=0)
    {
        throw IOException("unable to retrieve interface information");
    }
    
    //Windows device names are listed as "\Device\NPF_{DEVICE_ID}"
    //however, GetAdaptersInfo returns adapter names formatted
    //as "{DEVICE_ID}". Remove the beginning of the device name
    //before using it.
    string name=deviceName.substr(deviceName.find_first_of('{'));

    //Find specified device, if possible.
    PIP_ADAPTER_INFO ifaddr;
    for(ifaddr=ifList;ifaddr!=NULL;ifaddr=ifaddr->Next)
    {
        //Is this the specified device?
        if(name!=ifaddr->AdapterName)continue;

        memcpy(address,ifaddr->Address,6);
        break;
    }

    //No address found.
    if(ifaddr==NULL)
    {
        throw IOException("device not found");
    }
}

void RawSocketWin::Open(const std::string &deviceName) throw(IOException,
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

void RawSocketWin::Close()
{
    if(IsOpen())
    {
        pcap_close(device);
        device=NULL;
    }
}

void RawSocketWin::GetMACAddress(uint8_t *address) throw(IOException)
{
    if(deviceName=="")throw IOException("no device specified");

    memcpy(address,macAddress,6);
}

void RawSocketWin::Write(const void *buffer, size_t length) throw(SocketStateException)
{
    uint8_t dest[6]={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};

    Write(dest,buffer,length);
}

void RawSocketWin::Write(const uint8_t *dest, const void *buffer, size_t length) throw(SocketStateException)
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

    //Runt Ethernet frames are frames less than 64B
    //(payload size <46B). Pad the frame to avoid
    //sending a runt frame if necessary.
    if(length<(64-14))
    {
        memset(writeBuffer+14+length,0x00,(64-14)-length);
        length=64-14;
    }
    //FIXME Insert CRC if enabled?
    
    //FIXME Error check for socket closing?
    pcap_sendpacket(device,writeBuffer,14+length);
}
