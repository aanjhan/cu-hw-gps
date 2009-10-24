#ifndef SOCKET_EXCEPTIONS_HPP
#define SOCKET_EXCEPTIONS_HPP

#include "exceptions.hpp"

class SocketStateException : public IOException
{
public:
    SocketStateException(const std::string &msg="") : IOException(msg) {}
};

#endif
