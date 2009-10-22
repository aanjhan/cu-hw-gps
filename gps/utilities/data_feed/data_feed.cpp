#include "data_feed.hpp"

#include <iostream>

using namespace std;

DataFeed::DataFeed(const std::string &file,
                   RawSocket &socket,
                   long bitRate,
                   int burstSize) : socket(socket),
                                    burstSize(burstSize)
{
    running=false;

    long period=(1000*burstSize)/(bitRate/8);
    cout<<"rate="<<bitRate<<" bps, size="<<burstSize<<" B/frame"<<endl
        <<"period="<<period<<" ms/frame"<<endl;
    timeout=boost::posix_time::milliseconds(period);
}

DataFeed::~DataFeed()
{
    Stop();
}

void DataFeed::Start()
{
    if(running)return;
    
    running=true;
    thread=boost::thread(&DataFeed::RunFeed, this);
}

void DataFeed::Stop()
{
    if(!running)return;

    running=false;
    thread.join();
}

void DataFeed::RunFeed()
{
    uint8_t dest[6]={1,2,3,4,5,6};
    char *data=new char[burstSize];
    //char data[100];
    for(int i=0;i<burstSize;i++)data[i]=i;
        
    while(running)
    {
        cout<<"Sending "<<burstSize<<" bytes..."<<endl;
        
        //sock.Write(dest,data,length);
        socket.Write(data,burstSize);
    
        cout<<"Waiting..."<<endl;
        boost::this_thread::sleep(timeout);
    }

    delete[] data;
}
