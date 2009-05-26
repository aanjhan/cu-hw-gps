#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <string>
#include <boost/regex.hpp>
#include <exception>

namespace TokenType
{
    const int COLON    = 1;
    const int CONST    = 2;
    const int PLUS     = 3;
    const int MINUS    = 4;
    const int TIMES    = 5;
    const int DIVIDE   = 6;
    const int CARET    = 7;
    const int LPAREN   = 8;
    const int RPAREN   = 9;
    const int FUNCTION = 10;
    const int VARIABLE = 11;
    const int VALUE    = 12;
    const int NUMBER   = 12;
    const int HEX      = 13;
    const int ILLEGAL  = 14;
}

namespace CharType
{
    const int LETTER   = 1;
    const int NUMBER   = 2;
    const int PAREN    = 3;
    const int OPERATOR = 5;
    const int ILLEGAL  = 6;
}

class Tokenizer
{
public:
    class UnknownTokenException : public std::exception
    {
    public:
        UnknownTokenException(const std::string &token) : token(token), message("Unknown token '"+token+"'") {}
        ~UnknownTokenException() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        std::string GetToken(){ return token; }
        
    private:
        std::string message;
        std::string token;
    };
    
    class OutOfBoundsException : public std::exception
    {
    public:
        OutOfBoundsException() : message("Tokenizer read out of bounds.") {}
        ~OutOfBoundsException() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    Tokenizer(const std::string &expression);
    Tokenizer(const char *expression);

    bool HasNext();
    int NextType() throw(UnknownTokenException,OutOfBoundsException);
    std::string ReadNext() throw(OutOfBoundsException);

private:
    std::string expression;

    const static boost::regex verilogConstant;
    const static boost::regex hexValue;
    const static boost::regex number;
    const static boost::regex qualifiedName;

    void Initialize(const std::string &expression);
    int GetCharType(char c);
};

#endif
