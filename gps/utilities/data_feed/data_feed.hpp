#ifndef DATA_FEED_HPP
#define DATA_FEED_HPP

#include <string>
#include <boost/thread.hpp>
#include <boost/thread/mutex.hpp>
#include <boost/date_time.hpp>
#include "raw_socket.hpp"

class DataFeed
{
public:
    DataFeed(const std::string &file,
             RawSocket &socket,
             long bitRate,
             int burstSize);
    ~DataFeed();

    void Start();
    void Stop();

private:
    const static int AVG_WINDOW_SIZE = 100;
    
    bool running;
    RawSocket &socket;

    int burstSize;
    boost::posix_time::time_duration timeout;
    
    boost::thread feedThread;
    boost::thread dispThread;
    boost::mutex updateMutex;

    bool updatePending;
    long framesSent;
    unsigned long dt;
    unsigned long dtHistory[AVG_WINDOW_SIZE];

    void UpdateDisplay();
    void RunFeed();
};

#endif
