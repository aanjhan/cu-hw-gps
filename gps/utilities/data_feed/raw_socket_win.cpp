#include "raw_socket_win.hpp"
#include <pcap.h>
#include <iphlpapi.h>
#include <windows.h>

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
    if(pcap_findalldevs_ex(PCAP_SRC_IF_STRING, NULL, &ifList, errbuf)<0)
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
    if(GetAdaptersInfo(AdapterInfo,&dwBufLen)!=ERROR_SUCESS)
    {
        throw IOException("unable to retrieve interface information");
    }

    //Find specified device, if possible.
    PIP_ADAPTER_INFO ifaddr;
    for(ifaddr=ifList;ifaddr!=NULL;ifaddr=ifaddr->Next)
    {
        //Is this the specified device?
        if(deviceName!=ifaddr->AdapterName)continue;

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
    writeBuffer[12]=0x00;
    writeBuffer[13]=0x00;
    memcpy(writeBuffer+14,buffer,length);
    //FIXME Insert CRC if enabled?
    
    //FIXME Error check for socket closing?
    pcap_inject(device,writeBuffer,14+length);
}
