#ifndef PARSER_H
#define PARSER_H

#include <string.h>
#include <exception>
#include "tokenizer.h"
#include "tree_node.h"

class Parser
{
public:
    class SyntaxError : public std::exception
    {
    public:
        SyntaxError() : message("syntax error."), embed(false) {}
        SyntaxError(const std::string &error) : message(error+".") {}
        ~SyntaxError() throw() {}
        
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
    
    Parser(const std::string &expression) : tokenizer(Tokenizer(expression)) {}
    Parser(const char *expression) : tokenizer(Tokenizer(expression)) {}

    TreeNode* Parse() { return ParseExpression(); }

    static TreeNode* Parse(const char *expression){ return Parser(expression).Parse(); }
    static TreeNode* Parse(const std::string &expression){ return Parser(expression).Parse(); }

private:
    Tokenizer tokenizer;

    TreeNode* ParseExpression();
    TreeNode* ParseSum();
    TreeNode* ParseTerm();
    TreeNode* ParseFactor();
    TreeNode* ParseBase();
    TreeNode* ParseFunction();
    TreeNode* ParseValue();
    TreeNode* ParseVariable();
};

#endif
