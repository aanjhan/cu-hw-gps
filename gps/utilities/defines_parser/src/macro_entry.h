#ifndef MACRO_ENTRY_H
#define MACRO_ENTRY_H

#include "expression.h"

class MacroEntry
{
public:
    std::string file;
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
