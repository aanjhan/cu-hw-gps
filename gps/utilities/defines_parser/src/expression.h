#ifndef EXPRESSION_H
#define EXPRESSION_H

#include <map>
#include <boost/regex.hpp>
#include <exception>
#include <string>
#include "parser.h"
#include "tree_node.h"
#include "string_helper.hpp"

class Expression
{
public:
    class UnknownVariable : public std::exception
    {
    public:
        UnknownVariable(const std::string &var) : message("Error: unknown variable '"+var+"'.") {}
        ~UnknownVariable() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    class UnknownOperation : public std::exception
    {
    public:
        UnknownOperation(int type) : message("Error: unknown operation type "+StringHelper::ToString(type)+".") {}
        ~UnknownOperation() throw() {}
        virtual const char* what() const throw() { return message.c_str(); }
        
    private:
        std::string message;
    };
    
    Expression(TreeNode *tree) : tree(tree), evaluated(false) {}
    Expression(const std::string &expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    Expression(const char *expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    ~Expression();

    std::string Value(std::map<std::string,Expression*> &vars) throw(UnknownVariable,UnknownOperation);

protected:
    TreeNode *tree;
    
private:
    std::string value;
    bool evaluated;

    const static boost::regex number;

    static std::string Evaluate(TreeNode *tree, std::map<std::string,Expression*> &vars) throw(UnknownVariable,UnknownOperation);
    static double EvalValue(const std::string &valueString);
    static double EvalFunction(const std::string &function, double value);
};

#endif
