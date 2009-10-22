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

    long period=(1000000*burstSize)/(bitRate/8);
    cout<<"rate="<<bitRate<<" bps, size="<<burstSize<<" B/frame"
        <<", period="<<period<<" us/frame"<<endl;
    timeout=boost::posix_time::microseconds(period);
}

DataFeed::~DataFeed()
{
    Stop();
}

void DataFeed::Start()
{
    if(running)return;
    
    running=true;
    feedThread=boost::thread(&DataFeed::RunFeed, this);
    dispThread=boost::thread(&DataFeed::UpdateDisplay, this);
}

void DataFeed::Stop()
{
    if(!running)return;

    running=false;
    dispThread.join();
    feedThread.join();
}

void DataFeed::UpdateDisplay()
{
    char stats[100];

    while(running)
    {
        updateMutex.lock();
        if(framesSent>1)
        {
            //FIXME Scale rate units based on specified bit rate (pick unit/scaling in constructor).
            sprintf(stats,
                    "packets sent=%15ld, %ld, %ld, inst rate=%3.5f Mbps, avg rate=%3.5f Mbps",
                    framesSent,
                    dt,
                    totaldt,
                    static_cast<float>(burstSize*8)/(static_cast<float>(dt)),
                    static_cast<float>(burstSize*8)*(framesSent-1)/(static_cast<float>(totaldt)));
            cout<<"\r"<<stats<<flush;
        }
        updateMutex.unlock();
        
        boost::this_thread::sleep(boost::posix_time::milliseconds(200));
    }

    cout<<"\b\b  "<<endl;
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
        //FIXME Keep local framesSent value and update shared value
        //FIXME when you have the lock.
        if(updateMutex.try_lock())
        {
            framesSent++;
            updateMutex.unlock();
        }
        
        boost::this_thread::sleep(timeout);
        
        elapsedTime.stop();
        pc::epoch_type end=pc::get_epoch();

        //FIXME Store dt values instead of rate values.
        //FIXME Let update thread compute rates.
        dt=elapsedTime.get_microseconds();
        totaldt=pc::get_microseconds(feedStart,end);
    }

    delete[] data;
}
