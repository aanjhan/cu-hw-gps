#ifndef SOCKET_EXCEPTIONS_HPP
#define SOCKET_EXCEPTIONS_HPP

#include <stdexcept>
#include <string>

class IOException : public std::runtime_error
{
public:
    IOException(const std::string &msg="") : std::runtime_error(msg) {}
};

class SocketStateException : public IOException
{
public:
    SocketStateException(const std::string &msg="") : IOException(msg) {}
};

#endif
