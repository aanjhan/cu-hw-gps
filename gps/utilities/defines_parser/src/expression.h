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
    class ExpressionError : public std::exception
    {
    public:
        ExpressionError(const std::string &message) : variable(""), message(message), embed(false) {}
        ExpressionError(const std::string &variable,
                        const std::string &message) : variable(variable),
                                                      message(message),
                                                      embed(false){}
        ~ExpressionError() throw() {}

        void Embed(bool embed){ this->embed=embed; }
        void SetVariable(const std::string &variable){ this->variable=variable; }
        void SetMessage(const std::string &message){ this->message=message; }
        
        virtual const char* what() const throw()
        {
            std::string out="";
            if(!embed)
            {
                out="Error";
                if(variable!="")out+="("+variable+")";
                out+=": ";
            }
            else if(variable!="")out+="("+variable+") : ";
            out+=message;
            return out.c_str();
        }
        
    protected:
        bool embed;
        std::string variable;
        std::string message;
    };
    
    class UnsupportedFunction : public ExpressionError
    {
    public:
        UnsupportedFunction(const std::string &function) : ExpressionError("unsupported function '"+function+"'.") {}
        ~UnsupportedFunction() throw() {}
    };
    
    class UnknownVariable : public ExpressionError
    {
    public:
        UnknownVariable(const std::string &var) : ExpressionError("unknown variable '"+var+"'.") {}
        ~UnknownVariable() throw() {}
    };
    
    class UnknownOperation : public ExpressionError
    {
    public:
        UnknownOperation(int type) : ExpressionError("unknown operation type "+StringHelper::ToString(type)+".") {}
        ~UnknownOperation() throw() {}
    };
    
    Expression(TreeNode *tree) : tree(tree), evaluated(false) {}
    Expression(const std::string &expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    Expression(const char *expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    ~Expression();

    bool IsReprint(){ return tree->GetType()==TokenType::AT; }
    std::string Value(std::map<std::string,Expression*> &vars) throw(ExpressionError);

protected:
    TreeNode *tree;
    
private:
    std::string value;
    bool evaluated;

    const static boost::regex hexValue;
    const static boost::regex number;

    static std::string Evaluate(TreeNode *tree, std::map<std::string,Expression*> &vars) throw(ExpressionError);
    static double EvalValue(const std::string &valueString);
    static double EvalFunction(TreeNode *tree, std::map<std::string,Expression*> &vars) throw(ExpressionError);
    static double EvalFunction(const std::string &function, double value) throw(UnsupportedFunction);
};

#endif
