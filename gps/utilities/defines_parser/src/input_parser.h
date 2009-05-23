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

class InputParser
{
public:
    class Error : public std::exception
    {
    public:
        typedef enum { ERROR, WARNING, INFO } ErrorType;
        
        Error(const std::string &message) : type(ERROR), file(""), line(0), message(message) {}
        Error(const std::string &file, const std::string &message) : type(ERROR),
                                                                     file(file),
                                                                     line(0),
                                                                     message(message) {}
        Error(const std::string &file,int line,const std::string &message) : type(ERROR),
                                                                             file(file),
                                                                             line(line),
                                                                             message(message) {}
        ~Error() throw() {}

        void SetType(ErrorType type){ this->type=type; }
        void SetFile(const std::string &file){ this->file=file; }
        void SetLine(int line){ this->line=line; }
        void SetMessage(const std::string &message){ this->message=message; }
        
        virtual const char* what() const throw()
        {
            return ErrorString(type,file,line,message).c_str();
        }

        static void PrintWarning(const std::string &message){ PrintWarning("",0,message); }
        static void PrintWarning(const std::string &file,
                                 const std::string &message){ PrintWarning(file,0,message); }
        static void PrintWarning(const std::string &file,int line,const std::string &message);

        static void PrintError(const std::string &message){ PrintError("",0,message); }
        static void PrintError(const std::string &file,
                               const std::string &message){ PrintError(file,0,message); }
        static void PrintError(const std::string &file,int line,const std::string &message);
    
        static std::string ErrorString(ErrorType type,
                                       const std::string &file,
                                       int line,
                                       const std::string &message);
        
    protected:
        Error(ErrorType type,
              const std::string &file,
              int line,
              const std::string &message) : type(type),
                                            file(file),
                                            line(line),
                                            message(message) {}
        
        ErrorType type;
        std::string message;
        std::string file;
        int line;
    };
    
    class Warning : public Error
    {
    public:
        Warning(const std::string &message) : Error(WARNING,"",0,message) {}
        Warning(const std::string &file, const std::string &message) : Error(WARNING,file,0,message) {}
        Warning(const std::string &file,int line,const std::string &message) : Error(WARNING,file,line,message) {}
        ~Warning() throw() {}
    };
    
    InputParser() : useStdin(true), file("") {}
    InputParser(const std::string &file) : useStdin(false), file(file) {}

    void Parse(std::map<std::string,MacroEntry*> &vars, bool print=true) throw(Error);

private:
    bool useStdin;
    std::string file;

    enum FileType { CSV, XML };
    
    const static boost::regex fileName;
    const static boost::regex directive;
    const static boost::regex csvLine;
    const static boost::regex newLine;

    void ParseCSV(std::istream &in,
                  const std::string &currentFile,
                  std::map<std::string,MacroEntry*> &vars,
                  bool print=true) throw(Error);
    void ParseXML(std::istream &in,
                  const std::string &currentFile,
                  std::map<std::string,MacroEntry*> &vars,
                  bool print=true) throw(Error);
    void EvalDirective(const std::string &directive,
                       const std::string &parameter,
                       const std::string &currentFile,
                       int currentLine,
                       std::map<std::string,MacroEntry*> &vars,
                       bool print=true) throw(Error);
};

#endif
