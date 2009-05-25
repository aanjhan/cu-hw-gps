#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <string>
#include <boost/regex.hpp>
#include <exception>

namespace TokenType
{
    const int COLON    = 1;
    const int PLUS     = 2;
    const int MINUS    = 3;
    const int TIMES    = 4;
    const int DIVIDE   = 5;
    const int CARET    = 6;
    const int LPAREN   = 7;
    const int RPAREN   = 8;
    const int FUNCTION = 9;
    const int VARIABLE = 10;
    const int VALUE    = 11;
    const int NUMBER   = 11;
    const int ILLEGAL  = 12;
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
