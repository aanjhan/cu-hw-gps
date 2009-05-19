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
        SyntaxError() : message("Syntax error.") {}
        SyntaxError(const std::string &error) : message("Syntax error: "+error+".") {}
        ~SyntaxError() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
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
    TreeNode* ParseTerm();
    TreeNode* ParseFactor();
    TreeNode* ParseBase();
    TreeNode* ParseFunction();
    TreeNode* ParseValue();
    TreeNode* ParseVariable();
};

#endif
