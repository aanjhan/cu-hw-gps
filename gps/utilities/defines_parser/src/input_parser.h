#ifndef INPUT_PARSER_H
#define INPUT_PARSER_H

#include <string>
#include <map>
#include <exception>
#include <istream>
#include <boost/regex.hpp>
#include "expression.h"
#include "string_helper.hpp"

class InputParser
{
public:
    class SyntaxError : public std::exception
    {
    public:
        SyntaxError(const std::string &message) : message(message) {}
        SyntaxError(const std::string &file, const std::string &message) : message(file+": "+message) {}
        ~SyntaxError() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    class LineSyntaxError : public std::exception
    {
    public:
        LineSyntaxError(int line) : message("Warning: syntax error on line "+StringHelper::ToString(line)+", ignoring file.") {}
        ~LineSyntaxError() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    class FileNotFoundException : public std::exception
    {
    public:
        FileNotFoundException(const std::string &file) : message("Warning: unable to open file '"+file+"', ignoring.") {}
        ~FileNotFoundException() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    InputParser() : useStdin(true), file("") {}
    InputParser(const std::string &file) : useStdin(false), file(file) {}

    void Parse(std::map<std::string,Expression*> &vars) throw(SyntaxError,FileNotFoundException);

private:
    bool useStdin;
    std::string file;

    enum FileType { CSV, XML };
    
    const static boost::regex fileName;
    const static boost::regex csvLine;

    void ParseCSV(std::istream &in, std::map<std::string,Expression*> &vars) throw(LineSyntaxError);
    void ParseXML(std::istream &in, std::map<std::string,Expression*> &vars) throw(LineSyntaxError);
};

#endif
