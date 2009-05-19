#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <string>
#include <boost/regex.hpp>
#include <exception>

namespace TokenType
{
    const int PLUS     = 1;
    const int MINUS    = 2;
    const int TIMES    = 3;
    const int DIVIDE   = 4;
    const int CARET    = 5;
    const int LPAREN   = 6;
    const int RPAREN   = 7;
    const int FUNCTION = 8;
    const int VARIABLE = 9;
    const int VALUE    = 10;
    const int NUMBER   = 10;
    const int ILLEGAL  = 11;
}

namespace CharType
{
    const int LETTER   = 1;
    const int NUMBER   = 2;
    const int PAREN    = 3;
    const int OPERATOR = 4;
    const int ILLEGAL  = 5;
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
    int NextType() throw(UnknownTokenException);
    std::string ReadNext() throw(OutOfBoundsException);

private:
    std::string expression;

    const static boost::regex number;
    const static boost::regex qualifiedName;

    void Initialize(const std::string &expression);
    int GetCharType(char c);
};

#endif
