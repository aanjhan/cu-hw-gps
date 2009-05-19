#ifndef EXPRESSION_H
#define EXPRESSION_H

#include <map>
#include <boost/regex.hpp>
#include "parser.h"
#include "tree_node.h"

class Expression
{
public:
    Expression(TreeNode *tree) : tree(tree), evaluated(false) {}
    Expression(const std::string &expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    Expression(const char *expression) : tree(Parser::Parse(expression)), evaluated(false) {}
    ~Expression();

    std::string Value(std::map<std::string,Expression*> &vars);

protected:
    TreeNode *tree;
    
private:
    std::string value;
    bool evaluated;

    const static boost::regex number;

    static std::string Evaluate(TreeNode *tree, std::map<std::string,Expression*> &vars);
    static double EvalValue(const std::string &valueString);
    static double EvalFunction(const std::string &function, double value);
};

#endif
