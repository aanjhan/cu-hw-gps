#include "data_feed.hpp"
#include <iostream>
#include <string.h>
#include <platformstl/performance/performance_counter.hpp>

using namespace std;
typedef platformstl::performance_counter pc;

DataFeed::DataFeed(const std::string &file,
                   RawSocket &socket,
                   long bitRate,
                   int burstSize) : socket(socket),
                                    burstSize(burstSize)
{
    running=false;
    framesSent=0;

    long period=(1000*burstSize)/(bitRate/8);
    cout<<"rate="<<bitRate<<" bps, size="<<burstSize<<" B/frame"
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
    for(int i=0;i<burstSize;i++)data[i]=i;

    char stats[100];

    pc elapsedTime;
    pc::epoch_type feedStart;
    unsigned long dt, totaldt;

    feedStart=pc::get_epoch();
    
    while(running)
    {
        elapsedTime.start();
        //Send data.
        if(socket.IsOpen())
        {
            //socket.Write(dest,data,length);
            socket.Write(data,burstSize);
        }

        //Update statistics.
        //FIXME Update display in a separate thread to maintain timing.
        //FIXME Scale rate units based on specified bit rate (pick unit/scaling in constructor).
        //FIXME Fix average rate calculation (moving window?).
        framesSent++;
        if(framesSent>1)
        {
            sprintf(stats,
                    "packets sent=%15ld, %ld, %ld, inst rate=%3.5f Mbps, avg rate=%3.5f Mbps",
                    framesSent,
                    dt,
                    totaldt,
                    static_cast<float>(burstSize*8)/(static_cast<float>(dt)),
                    static_cast<float>(burstSize*8)*framesSent/(static_cast<float>(totaldt)));
            cout<<"\r"<<stats<<flush;
        }
        
        boost::this_thread::sleep(timeout);
        
        elapsedTime.stop();
        pc::epoch_type end=pc::get_epoch();
        
        dt=elapsedTime.get_microseconds();
        totaldt=pc::get_microseconds(feedStart,end);
    }

    cout<<"\b\b  "<<endl;

    delete[] data;
}
