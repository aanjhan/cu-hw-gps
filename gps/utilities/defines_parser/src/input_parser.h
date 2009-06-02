#ifndef INPUT_PARSER_H
#define INPUT_PARSER_H

#include <string>
#include <map>
#include <exception>
#include <istream>
#include <boost/regex.hpp>
#include "macro_entry.h"
#include "expression.h"
#include "string_helper.hpp"

class InputErrors
{
public:
    typedef enum { ERROR, WARNING, INFO } ErrorType;
    
    static void PrintWarning(const std::string &file,int line,const std::string &message);
    static void PrintWarning(const std::string &file,
                             const std::string &message){ PrintWarning(file,0,message); }
    static void PrintWarning(const std::string &message){ PrintWarning("",0,message); }

    static void PrintError(const std::string &file,int line,const std::string &message);
    static void PrintError(const std::string &file,
                           const std::string &message){ PrintError(file,0,message); }
    static void PrintError(const std::string &message){ PrintError("",0,message); }
    
    static std::string ErrorString(ErrorType type,
                                   const std::string &file,
                                   int line,
                                   const std::string &message);
};

class InputParser
{
public:
    InputParser() : useStdin(true), file("") {}
    InputParser(const std::string &file) : useStdin(false), file(file) {}

    int Parse(std::map<std::string,MacroEntry*> &vars, bool print=true);
    
private:
    bool useStdin;
    std::string file;

    enum FileType { CSV, XML };
    
    const static boost::regex fileName;
    const static boost::regex comment;
    const static boost::regex directive;
    const static boost::regex csvLine;
    const static boost::regex newLine;

    int ParseCSV(std::istream &in,
                 const std::string &currentFile,
                 std::map<std::string,MacroEntry*> &vars,
                 bool print=true);
    int ParseXML(std::istream &in,
                 const std::string &currentFile,
                 std::map<std::string,MacroEntry*> &vars,
                 bool print=true);
    int EvalDirective(const std::string &directive,
                      const std::string &parameter,
                      const std::string &currentFile,
                      int currentLine,
                      std::map<std::string,MacroEntry*> &vars,
                      bool print=true);
};

#endif
