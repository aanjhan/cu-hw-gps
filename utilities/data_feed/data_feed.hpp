#ifndef DATA_FEED_HPP
#define DATA_FEED_HPP

#include <fstream>
#include <string>
#include <stdint.h>
#include "exceptions.hpp"
#include "raw_socket.hpp"

//FIXME This doesn't work because of defines. Is there
//FIXME a better way to do the generics?
//class RawSocket;

namespace boost
{
    namespace posix_time
    {
        class time_duration;
    }
    class thread;
    class mutex;
}

class DataFeed
{
public:
    DataFeed(const std::string &fileName,
             RawSocket &socket,
             long bitRate,
             int burstSize) throw(IOException);
    ~DataFeed();

    void SetLength(int length);

    void Start();
    void StartAndWait();
    void Stop();

    bool IsRunning() const;

private:
    const static int AVG_WINDOW_SIZE = 100;
    
    bool running;
    RawSocket &socket;

    long bitRate;
    int burstSize;
    uint8_t numSegments;
    uint16_t finalSegSize;
    boost::posix_time::time_duration *timeout;

    std::string fileName;
    std::ifstream file;
    int fileLength;
    
    boost::thread *feedThread;
    boost::thread *dispThread;
    boost::mutex *updateMutex;

    bool updatePending;
    long framesSent;
    unsigned long dt;
    unsigned long dtHistory[AVG_WINDOW_SIZE];

    void UpdateDisplay();
    
    void DisplayThread();
    void FeedThread();
};

#endif
