#include "parser.h"

using namespace std;

/**
* Parse next expression.
* Expressions are defined as: [-] Term { (+ | -) Term }
*/
TreeNode* Parser::ParseExpression()
{
    if(!tokenizer.HasNext())return NULL;

    try
    {
        //Read initial minus sign.
        bool minus=(tokenizer.NextType()==TokenType::MINUS);
        if(minus)tokenizer.ReadNext();

        TreeNode *expression=ParseTerm();//Get term
        if(expression==NULL)throw SyntaxError("no term for expression");//Syntax error
    
        if(minus)expression=new TreeNode(TokenType::MINUS,new TreeNode(TokenType::NUMBER,"0"),expression);//Make negative
    
        while(tokenizer.HasNext() &&
              (tokenizer.NextType()==TokenType::PLUS ||
               tokenizer.NextType()==TokenType::MINUS))
        {
            TreeNode *t=new TreeNode(tokenizer.NextType(),NULL,NULL);
            t->SetLeft(expression);
            expression=t;
            //expression=new TreeNode(tokenizer.NextType(),expression,NULL);//Create expression and move old left
            tokenizer.ReadNext();//Eat sign
            TreeNode *right=ParseTerm();//Get second term
            //Syntax error
            if(right==NULL)
            {
                delete expression;
                throw SyntaxError("missing right term");
            }
            expression->SetRight(right);//Set right
        }
    
        return expression;
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
    catch(...){ throw; }
}

/**
* Parse next term.
* Terms are defined as: Factor { ( * | / ) Factor }
*/
TreeNode* Parser::ParseTerm()
{
    if(!tokenizer.HasNext())return NULL;//Nothing left
    
    TreeNode *term=ParseFactor();//Get factor
    if(term==NULL)return NULL;//Syntax error
    
    while(tokenizer.NextType()==TokenType::TIMES ||
          tokenizer.NextType()==TokenType::DIVIDE)
    {
        term=new TreeNode(tokenizer.NextType(),term,NULL);//Create new node and move old term left
        tokenizer.ReadNext();//Eat sign
        TreeNode *right=ParseFactor();//Get second operand
        //Syntax error
        if(right==NULL)
        {
            delete term;
            return NULL;
        }
        term->SetRight(right);//Set right
    }
    
    return term;//Return term
}

/**
* Parse next factor.
* Factors are defined as: Base [ ^ [-] Number ]
*/
TreeNode* Parser::ParseFactor()
{
    if(!tokenizer.HasNext())return NULL;//Nothing left
    
    TreeNode *base=ParseBase();//Get base
    if(tokenizer.NextType()==TokenType::CARET)
    {
        tokenizer.ReadNext();//Eat carrot
        bool minus=(tokenizer.NextType()==TokenType::MINUS);//Minus sign?
        if(minus)tokenizer.ReadNext();//Eat minus
        TreeNode *exponent=ParseValue();//Get number
        //Syntax error
        if(exponent==NULL)
        {
            delete base;
            return NULL;
        }
        else if(minus){
            exponent=new TreeNode(TokenType::MINUS,
                                  new TreeNode(TokenType::NUMBER,"0"),
                                  exponent);//Make negative
        }
        return new TreeNode(TokenType::CARET,base,exponent);//Return factor
    }
    else return base;//Return base alone
}

/**
* Parse next base.
* Bases are defined as:
* Number | Variable | Function ( Expression )
*/
TreeNode* Parser::ParseBase()
{
    switch(tokenizer.NextType()){
    case TokenType::NUMBER: return ParseValue();
    case TokenType::VARIABLE: return ParseVariable();
    case TokenType::FUNCTION: return ParseFunction();
    default:
        if(tokenizer.NextType()!=TokenType::LPAREN)return NULL;//Invalid syntax
        tokenizer.ReadNext();//Eat paren
        TreeNode *expression=ParseExpression();
        if(expression==NULL)return NULL;
        else if(tokenizer.NextType()!=TokenType::RPAREN)
        {
            delete expression;
            return NULL;//Invalid syntax
        }
        tokenizer.ReadNext();//Eat paren
        return expression;
    }
}

/**
* Parse next function.
* Functions are defined as: Function ( Expression )
*/
TreeNode* Parser::ParseFunction()
{
    if(!tokenizer.HasNext())return NULL;//Nothing left
    
    if(tokenizer.NextType()!=TokenType::FUNCTION)return NULL;//Expected function next

    string functionName=tokenizer.ReadNext();
    TreeNode *function=new TreeNode(TokenType::FUNCTION,functionName);//Parse and return leaf (value 0 for non-leaf)
    if(function==NULL)return NULL;

    //Invalid syntax - missing paren
    if(tokenizer.NextType()!=TokenType::LPAREN)
    {
        delete function;
        return NULL;
    }
    tokenizer.ReadNext();//Eat paren
    
    TreeNode *expression=ParseExpression();
    //Invalid syntax - no expression
    if(expression==NULL)
    {
        delete function;
        return NULL;
    }
    else function->SetRight(expression);

    //Invalid syntax - missing paren
    if(tokenizer.NextType()!=TokenType::RPAREN)
    {
        delete function;
        delete expression;
        return NULL;
    }
    tokenizer.ReadNext();//Eat paren
    
    return function;//Return function
}

TreeNode* Parser::ParseValue()
{
    if(!tokenizer.HasNext() ||
       tokenizer.NextType()!=TokenType::VALUE)
        return NULL;//Expected number next
    else return new TreeNode(tokenizer.NextType(),tokenizer.ReadNext());//Parse int and return leaf
}

TreeNode* Parser::ParseVariable()
{
    if(!tokenizer.HasNext() ||
       tokenizer.NextType()!=TokenType::VARIABLE)
        return NULL;//Expected number next
    else return new TreeNode(tokenizer.NextType(),tokenizer.ReadNext());//Parse int and return leaf
}

