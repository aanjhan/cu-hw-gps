#ifndef __string_helper_hpp__
#define __string_helper_hpp__

#include <string>
#include <sstream>
#include <ctype.h>
#include <algorithm>

namespace StringHelper
{
    template<class T>
    inline std::string ToString(const T& value)
    {
        std::ostringstream o;
        if(!(o<<value))return std::string("");
        return o.str();
    }

    template<class T>
    inline T& FromString(const std::string& str, T& value, const T& defaultValue=0)
    {
        std::istringstream i(str);
        if(!(i>>value))
        {
            value=defaultValue;
            return value;
        }
        return value;
    }

    template<class T>
    inline T& FromString(const char* str, T& value, const T& defaultValue=0)
    {
        return FromString(std::string(str),value,defaultValue);
    }

    inline bool IsInt(const std::string& str)
    {
        std::istringstream i(str);
        int value;
        i>>value;
        return !(i.rdstate() & std::ios_base::failbit) && str.find(".")==std::string::npos;
    }

    inline bool IsFloat(const std::string& str)
    {
        std::istringstream i(str);
        float value;
        i>>value;
        return !(i.rdstate() & std::ios_base::failbit);
    }

    inline bool IsDouble(const std::string& str)
    {
        std::istringstream i(str);
        double value;
        i>>value;
        return !(i.rdstate() & std::ios_base::failbit);
    }

    inline std::string ToUpper(std::string str)
    {
        std::transform(str.begin(),str.end(),str.begin(),(int(*)(int))toupper);
        return str;
    }

    inline std::string ToLower(std::string str)
    {
        std::transform(str.begin(),str.end(),str.begin(),(int(*)(int))tolower);
        return str;
    }
}

#endif
