#include "tokenizer.h"

using namespace std;

const boost::regex Tokenizer::number("^(\\d+(\\.\\d+)?(e-?\\d+)?)");
const boost::regex Tokenizer::qualifiedName("^(`?[A-Za-z_]\\w*)");

Tokenizer::Tokenizer(const std::string &expression)
{
    Initialize(expression);
}

Tokenizer::Tokenizer(const char *expression)
{
    Initialize(string(expression));
}

bool Tokenizer::HasNext()
{
    return expression.length()!=0;
}

int Tokenizer::NextType() throw(UnknownTokenException)
{
    boost::smatch m;

    //Is this a number?
    if(boost::regex_search(expression,number))
    {
        return TokenType::NUMBER;
    }
    //Is this a qualified name (variable or function)?
    else if(boost::regex_search(expression,m,qualifiedName))
    {
        if(expression.length()>m[1].length() &&
           expression[m[1].length()]=='(')
            return TokenType::FUNCTION;
        else return TokenType::VARIABLE;
    }
    else
    {
        switch(expression[0])
        {
        case '+': return TokenType::PLUS;
        case '-': return TokenType::MINUS;
        case '*': return TokenType::TIMES;
        case '/': return TokenType::DIVIDE;
        case '^': return TokenType::CARET;
        case '(': return TokenType::LPAREN;
        case ')': return TokenType::RPAREN;
        default: throw UnknownTokenException(expression.substr(0,1));
        }
    }
}

std::string Tokenizer::ReadNext() throw(OutOfBoundsException)
{
    boost::smatch m;

    if(expression.length()==0)throw OutOfBoundsException();

    //Is this a number of qualified name (variable or function)?
    if(boost::regex_search(expression,m,number) ||
       boost::regex_search(expression,m,qualifiedName))
    {
        try{ expression=expression.substr(m[1].length()); }
        catch(out_of_range e){}
        return m[1];
    }
    else
    {
        string s=expression.substr(0,1);
        try{ expression=expression.substr(1); }
        catch(out_of_range e){}
        return s;
    }
}

void Tokenizer::Initialize(const std::string &expression)
{
    this->expression=expression;
}
