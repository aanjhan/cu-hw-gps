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

    for(int i=0;i<AVG_WINDOW_SIZE;i++)dtHistory[i]=0;

    long period=static_cast<long>((1000000*static_cast<float>(burstSize))/(static_cast<float>(bitRate)/8)+0.5);
    cout<<"rate="<<bitRate<<" bps"
        <<", size="<<burstSize<<" B/frame"
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
    float avgdt;

    while(running)
    {
        updateMutex.lock();
        if(framesSent>1)
        {
            avgdt=0;
            for(int i=0;i<AVG_WINDOW_SIZE;i++)avgdt+=static_cast<float>(dtHistory[i]);
            avgdt/=AVG_WINDOW_SIZE;
            
            //FIXME Scale rate units based on specified bit rate (pick unit/scaling in constructor).
            sprintf(stats,
                    "bursts sent=%15ld, inst rate=%3.5f Mbps, avg rate=%3.5f Mbps",
                    framesSent,
                    static_cast<float>(burstSize*8)/(static_cast<float>(dt)),
                    static_cast<float>(burstSize*8)/avgdt);
            cout<<"\r"<<stats<<flush;
        }
        updateMutex.unlock();
        
        boost::this_thread::sleep(boost::posix_time::milliseconds(100));
    }

    cout<<"\b\b  "<<endl;
}

void DataFeed::RunFeed()
{
    uint8_t dest[6]={1,2,3,4,5,6};

    //Determine frame segmenting information.
    uint8_t numSegments=(uint8_t)(burstSize/RAW_SOCKET_MTU)+1;
    uint16_t finalSegSize=(uint16_t)(burstSize%RAW_SOCKET_MTU);
    uint16_t maxFrameSize=(uint16_t)(numSegments>1 ? RAW_SOCKET_MTU : burstSize);

    cout<<"# segments="<<(int)numSegments<<", MTU="<<RAW_SOCKET_MTU<<" B, final segment size="<<finalSegSize<<" B"<<endl;
    
    char *data=new char[maxFrameSize];
    for(int i=0;i<maxFrameSize;i++)data[i]=i;

    int histIndex=0;
    long frameCount=0;
    pc elapsedTime;
    
    while(running)
    {
        elapsedTime.start();
        //Send segmented data frame.
        if(socket.IsOpen())
        {
            for(int i=0;i<numSegments;i++)
            {
                //socket.Write(dest,data,length);
                if(i<numSegments-1)socket.Write(data,RAW_SOCKET_MTU);
                else socket.Write(data,finalSegSize);
            }
        }
        
        boost::this_thread::sleep(timeout);
        
        elapsedTime.stop();
        frameCount++;

        //Update statistics if possible.
        if(updateMutex.try_lock())
        {
            framesSent=frameCount;

            long currentdt=elapsedTime.get_microseconds();
            dtHistory[histIndex++]=currentdt;
            if(histIndex==AVG_WINDOW_SIZE)histIndex=0;
            dt=currentdt;
            
            updateMutex.unlock();
        }
    }

    delete[] data;
}
