#include "data_feed.hpp"
#include <string.h>
#include <iostream>
#include <boost/thread.hpp>
#include <boost/thread/mutex.hpp>
#include <boost/date_time.hpp>
#include <platformstl/performance/performance_counter.hpp>

#define SAFE_DELETE(x) if(x!=NULL)delete x; x=NULL;

using namespace std;
typedef platformstl::performance_counter pc;

DataFeed::DataFeed(const std::string &fileName,
                   RawSocket &socket,
                   long bitRate,
                   int burstSize) throw(IOException) :
    running(false),
    finished(true),
    socket(socket),
    bitRate(bitRate),
    burstSize(burstSize),
    fileName(fileName),
    framesSent(0)
{
    for(int i=0;i<AVG_WINDOW_SIZE;i++)dtHistory[i]=0;

    //Open file for reading and determine length.
    file.open(fileName.c_str(),ios_base::in|ios_base::binary);
    if(!file.good())
    {
        throw IOException("unable to open file '"+fileName+"'");
    }
    file.seekg(0,ios::end);
    fileLength=file.tellg();
    file.seekg(0,ios::beg);

    feedThread=NULL;
    dispThread=NULL;
    updateMutex=new boost::mutex();

    //Determine interrupt period for desired data rate.
    long period=static_cast<long>((1000000*static_cast<float>(burstSize))/(static_cast<float>(bitRate)/8)+0.5);
    cout<<"rate="<<bitRate<<" bps"
        <<", size="<<burstSize<<" B/frame"
        <<", period="<<period<<" us/frame"<<endl;
    timeout=new boost::posix_time::microseconds(period);
}

DataFeed::~DataFeed()
{
    Stop();
    if(file.is_open())file.close();

    SAFE_DELETE(feedThread);
    SAFE_DELETE(dispThread);
    SAFE_DELETE(updateMutex);
    SAFE_DELETE(timeout);
}

void DataFeed::Start()
{
    if(running)return;
    
    running=true;
    finished=false;
    feedThread=new boost::thread(&DataFeed::RunFeed, this);
    dispThread=new boost::thread(&DataFeed::UpdateDisplay, this);
}

void DataFeed::Stop()
{
    if(!running)return;
    
    finished=true;
    dispThread->join();
    feedThread->join();
    running=false;
    
    SAFE_DELETE(feedThread);
    SAFE_DELETE(dispThread);
}

void DataFeed::UpdateDisplay()
{
    char stats[100];
    float avgdt;

    while(!finished)
    {
        updateMutex->lock();
        //Calculate average dt.
        avgdt=0;
        for(int i=0;i<AVG_WINDOW_SIZE;i++)avgdt+=static_cast<float>(dtHistory[i]);
        avgdt/=AVG_WINDOW_SIZE;

        //Print statistics.
        //FIXME Scale rate units based on specified bit rate (pick unit/scaling in constructor).
        sprintf(stats,
                "bursts sent=%15ld, inst rate=%3.5f Mbps, avg rate=%3.5f Mbps",
                framesSent,
                static_cast<float>(burstSize*8)/(static_cast<float>(dt)),
                static_cast<float>(burstSize*8)/avgdt);
        cout<<"\r"<<stats<<flush;
        updateMutex->unlock();
        
        boost::this_thread::sleep(boost::posix_time::milliseconds(100));
    }

    cout<<"\b\b  "<<endl;
}

void DataFeed::RunFeed()
{
    bool finished=false;
    int histIndex=0;
    long frameCount=0;
    pc elapsedTime;
    int segLength;
    char data[RAW_SOCKET_MTU];
    
    uint8_t dest[6]={1,2,3,4,5,6};

    //Determine frame segmenting information.
    uint8_t numSegments=(uint8_t)(burstSize/RAW_SOCKET_MTU)+1;
    uint16_t finalSegSize=(uint16_t)(burstSize%RAW_SOCKET_MTU);

    cout<<"# segments="<<(int)numSegments
        <<", MTU="<<RAW_SOCKET_MTU<<" B"
        <<", final segment size="<<finalSegSize<<" B"<<endl;
    
    while(!finished)
    {
        elapsedTime.start();
        
        //Send segmented data burst.
        if(socket.IsOpen())
        {
            for(int i=0;i<numSegments;i++)
            {
                //Determine segment length.
                if(i==numSegments-1)segLength=finalSegSize;
                else segLength=RAW_SOCKET_MTU;
                if(segLength>fileLength)segLength=fileLength;
                
                //Read next data segment.
                file.read(data,segLength);
                fileLength-=segLength;

                //Write data.
                //socket.Write(dest,data,segLength);
                socket.Write(data,segLength);

                //Check for eof.
                if(fileLength==0)
                {
                    finished=true;
                    break;
                }
            }
        }
        frameCount++;
        
        boost::this_thread::sleep(*timeout);
        
        elapsedTime.stop();

        //Update statistics if possible.
        if(updateMutex->try_lock())
        {
            framesSent=frameCount;

            long currentdt=elapsedTime.get_microseconds();
            dtHistory[histIndex++]=currentdt;
            if(histIndex==AVG_WINDOW_SIZE)histIndex=0;
            dt=currentdt;
            
            updateMutex->unlock();
        }
    }

    //FIXME Interrupt shouldn't be necessary but thread seems to
    //FIXME deadlock when finished goes true.
    dispThread->interrupt();
    dispThread->join();
    cout<<endl;
    cout<<"Sent "<<frameCount<<" frames."<<endl;
    
    running=false;
}
