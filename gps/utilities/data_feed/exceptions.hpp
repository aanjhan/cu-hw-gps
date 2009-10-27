#ifndef EXCEPTIONS_HPP
#define EXCEPTIONS_HPP

#include <stdexcept>
#include <string>

class IOException : public std::runtime_error
{
public:
    IOException(const std::string &msg="") : std::runtime_error(msg) {}
};

#endif
