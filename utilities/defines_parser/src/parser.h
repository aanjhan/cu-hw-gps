#ifndef PARSER_H
#define PARSER_H

#include <string.h>
#include <exception>
#include "tokenizer.h"
#include "tree_node.h"

class Parser
{
public:
    class ParserError : public std::exception
    {
    public:
        ParserError(const std::string &error) : message(error+".") {}
        ~ParserError() throw() {}
        
        void Embed(bool embed){ this->embed=embed; }
        
        virtual const char* what() const throw()
        {
            std::string out;
            if(!embed)
            {
                out="Parser error: ";
            }
            else out="parser error : ";
            out+=message;
            return out.c_str();
        }
        
    private:
        bool embed;
        std::string message;
    };
    
    class SyntaxError : public ParserError
    {
    public:
        SyntaxError() : ParserError("syntax error") {}
        SyntaxError(const std::string &error) : ParserError(error) {}
        ~SyntaxError() throw() {}
    };
    
    Parser(const std::string &expression) : tokenizer(Tokenizer(expression)) {}
    Parser(const char *expression) : tokenizer(Tokenizer(expression)) {}

    TreeNode* Parse() throw(ParserError);

    static TreeNode* Parse(const char *expression) throw(ParserError) { return Parser(expression).Parse(); }
    static TreeNode* Parse(const std::string &expression) throw(ParserError) { return Parser(expression).Parse(); }

private:
    Tokenizer tokenizer;

    TreeNode* ParseExpression() throw(SyntaxError);
    TreeNode* ParseSum() throw(SyntaxError);
    TreeNode* ParseTerm() throw(SyntaxError);
    TreeNode* ParseFactor() throw(SyntaxError);
    TreeNode* ParseBase() throw(SyntaxError);
    TreeNode* ParseFunction() throw(SyntaxError);
    TreeNode* ParseValue() throw(SyntaxError);
    TreeNode* ParseHex() throw(SyntaxError);
    TreeNode* ParseVariable() throw(SyntaxError);
};

#endif
