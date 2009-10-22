#ifndef DATA_FEED_HPP
#define DATA_FEED_HPP

#include <string>
#include <boost/thread.hpp>
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

    void RunFeed();

private:
    bool running;
    RawSocket &socket;
    boost::thread thread;

    int burstSize;
    boost::posix_time::time_duration timeout;
};

#endif
