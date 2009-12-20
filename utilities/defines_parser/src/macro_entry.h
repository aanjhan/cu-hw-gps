#ifndef MACRO_ENTRY_H
#define MACRO_ENTRY_H

#include "expression.h"
#include <boost/filesystem.hpp>

class MacroEntry
{
public:
    boost::filesystem::path file;
    int line;
    
    bool print;
    Expression *expression;
    std::string comments;

    MacroEntry() : print(false), expression(NULL) {}
    ~MacroEntry()
    {
        if(expression!=NULL)delete expression;
    }
};

#endif
