#include <math.h>
#include <stdlib.h>
#include "expression.h"
#include "string_helper.hpp"

using namespace std;
using namespace StringHelper;

const boost::regex Expression::number("^(\\d+(\\.\\d+)?)(e(-?\\d+))?$");

Expression::~Expression()
{
    if(tree!=NULL)delete tree;
}

string Expression::Value(std::map<std::string,Expression*> &vars)
{
    if(!evaluated)
    {
        value=Evaluate(tree,vars);
        evaluated=true;
    }
    return value;
}

std::string Expression::Evaluate(TreeNode *tree, std::map<std::string,Expression*> &vars)
{
    //Convert left parameter to a double.
    string leftString;
    double leftValue;
    bool haveLeftValue=false;
    if(tree->GetLeft()!=NULL)
    {
        leftString=Evaluate(tree->GetLeft(),vars);
        if(IsDouble(leftString))
        {
            haveLeftValue=true;
            FromString(leftString,leftValue);
        }
    }
    
    //Convert right parameter to a double.
    string rightString;
    double rightValue;
    bool haveRightValue=false;
    if(tree->GetRight()!=NULL)
    {
        rightString=Evaluate(tree->GetRight(),vars);
        if(IsDouble(rightString))
        {
            haveRightValue=true;
            FromString(rightString,rightValue);
        }
    }
    
    switch(tree->GetType())
    {
    case TokenType::PLUS:
        if(haveLeftValue && haveRightValue)return ToString(leftValue+rightValue);
        else return leftString+"+"+rightString;
    case TokenType::MINUS:
        if(haveLeftValue && haveRightValue)return ToString(leftValue-rightValue);
        else return leftString+"-"+rightString;
    case TokenType::TIMES:
        if(haveLeftValue && haveRightValue)return ToString(leftValue/rightValue);
        else return leftString+"*"+rightString;
    case TokenType::DIVIDE:
        if(haveLeftValue && haveRightValue)return ToString(leftValue/rightValue);
        else return leftString+"/"+rightString;
    case TokenType::CARET:
        if(haveLeftValue && haveRightValue)return ToString(pow(leftValue,rightValue));
        else return leftString+"^"+rightString;
    case TokenType::FUNCTION:
        if(haveRightValue)return ToString(EvalFunction(tree->GetValue(),rightValue));
        else return tree->GetValue()+"("+rightString+")";
    case TokenType::VARIABLE:
        if(tree->GetValue()[0]=='`')return tree->GetValue();
        else if(vars.find(tree->GetValue())==vars.end())return 0;//FIXME Throw exception.
        else return vars[tree->GetValue()]->Value(vars);
    case TokenType::VALUE: return ToString(EvalValue(tree->GetValue()));
    default: return "0";//FIXME Throw exception.
    }
}

double Expression::EvalValue(const std::string &valueString)
{
    double value;
    boost::smatch m;

    if(boost::regex_match(valueString,m,number))
    {
        string s=m[1];
        value=atof(s.c_str());
        if(m[4].matched)
        {
            s=m[4];
            value*=pow(10,atoi(s.c_str()));
        }
        return value;
    }
    else return 0;
}

double Expression::EvalFunction(const std::string &function, double value)
{
    if(function=="abs")return value<0 ? -value : value;
    else if(function=="acos")return acos(value);
    else if(function=="asin")return asin(value);
    else if(function=="atan")return atan(value);
    else if(function=="ceil")return ceil(value);
    else if(function=="cos")return cos(value);
    else if(function=="exp")return exp(value);
    else if(function=="floor")return floor(value);
    else if(function=="ln")return log(value);
    else if(function=="log10")return log10(value);
    else if(function=="log2")return log2(value);
    else if(function=="sin")return sin(value);
    else if(function=="sqrt")return sqrt(value);
    else if(function=="tan")return tan(value);
    else return 0;
}
