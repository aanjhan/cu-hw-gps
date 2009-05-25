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

string Expression::Value(std::map<std::string,Expression*> &vars) throw(ExpressionError)
{
    if(!evaluated)
    {
        value=Evaluate(tree,vars);
        evaluated=true;
    }
    return value;
}

std::string Expression::Evaluate(TreeNode *tree, std::map<std::string,Expression*> &vars) throw(ExpressionError)
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

    bool useValue=false;
    double value;
    string stringValue;
    switch(tree->GetType())
    {
    case TokenType::PLUS:
        if(haveLeftValue && haveRightValue)
        {
            useValue=true;
            value=leftValue+rightValue;
        }
        else stringValue=leftString+"+"+rightString;
        break;
    case TokenType::MINUS:
        if(haveLeftValue && haveRightValue)
        {
            useValue=true;
            value=leftValue-rightValue;
        }
        else stringValue=leftString+"-"+rightString;
        break;
    case TokenType::TIMES:
        if(haveLeftValue && haveRightValue)
        {
            useValue=true;
            value=leftValue*rightValue;
        }
        else stringValue=leftString+"*"+rightString;
        break;
    case TokenType::DIVIDE:
        if(haveLeftValue && haveRightValue)
        {
            useValue=true;
            value=leftValue/rightValue;
        }
        else stringValue=leftString+"/"+rightString;
        break;
    case TokenType::CARET:
        if(haveLeftValue && haveRightValue)
        {
            useValue=true;
            value=pow(leftValue,rightValue);
        }
        else stringValue=leftString+"^"+rightString;
        break;
    case TokenType::COLON:
        stringValue=leftString+":"+rightString;
        break;
    case TokenType::FUNCTION:
        if(haveRightValue)
        {
            useValue=true;
            value=EvalFunction(tree->GetValue(),rightValue);
        }
        else stringValue=tree->GetValue()+"("+rightString+")";
        break;
    case TokenType::VARIABLE:
        if(tree->GetValue()[0]=='`')stringValue=tree->GetValue();
        else if(vars.find(tree->GetValue())==vars.end())throw UnknownVariable(tree->GetValue());
        else stringValue=vars[tree->GetValue()]->Value(vars);
        break;
    case TokenType::VALUE:
        useValue=true;
        value=EvalValue(tree->GetValue());
        break;
    default: throw UnknownOperation(tree->GetType());
    }

    if(useValue)
    {
        double diff;
        diff=value-floor(value+0.5);
        if(diff<=1e-4)return ToString((int64_t)floor(value+0.5));
        else return ToString(value);
    }
    else return stringValue;
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
    else if(function=="max_value")return pow(2,floor(value))-1;
    else if(function=="max_width")return ceil(log2(ceil(value)));
    else if(function=="round")return floor(value+0.5);
    else if(function=="sin")return sin(value);
    else if(function=="sqrt")return sqrt(value);
    else if(function=="tan")return tan(value);
    else return 0;
}
