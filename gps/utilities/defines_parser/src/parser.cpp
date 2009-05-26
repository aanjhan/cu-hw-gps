#include "parser.h"

using namespace std;

TreeNode* Parser::Parse() throw(ParserError)
{
    TreeNode *expression=ParseExpression();

    if(tokenizer.HasNext())
    {
        delete expression;
        throw ParserError("characters remaining in expression");
    }
    
    return expression;
}

/**
* Parse next expression.
* Expressions are defined as: Sum [ : Sum | '[hdb] Expression ]
*/
TreeNode* Parser::ParseExpression() throw(SyntaxError)
{
    //Read range.
    TreeNode *expression=ParseSum();

    try
    {
        if(tokenizer.HasNext())
        {
            if(tokenizer.NextType()==TokenType::COLON)
            {
                tokenizer.ReadNext();
                expression=new TreeNode(TokenType::COLON,expression,NULL);

                TreeNode *right;
                try{ right=ParseSum(); }//Get second term
                catch(...){ delete expression; throw; }
                expression->SetRight(right);
            }
            else if(tokenizer.NextType()==TokenType::CONST)
            {
                expression=new TreeNode(TokenType::CONST,expression,NULL);
                expression->SetValue(tokenizer.ReadNext());
        
                TreeNode *right;
                try{ right=ParseSum(); }//Get second term
                catch(...){ delete expression; throw; }
                expression->SetRight(right);
            }
        }
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
    
    return expression;
}

/**
* Parse next sum.
* Sums are defined as: [-] Term { (+ | -) Term }
*/
TreeNode* Parser::ParseSum() throw(SyntaxError)
{
    try
    {
        //Read initial minus sign.
        bool minus=(tokenizer.NextType()==TokenType::MINUS);
        if(minus)tokenizer.ReadNext();

        TreeNode *expression=ParseTerm();//Get term
    
        if(minus)expression=new TreeNode(TokenType::MINUS,new TreeNode(TokenType::NUMBER,"0"),expression);//Make negative
    
        while(tokenizer.HasNext() &&
              (tokenizer.NextType()==TokenType::PLUS ||
               tokenizer.NextType()==TokenType::MINUS))
        {
            TreeNode *t=new TreeNode(tokenizer.NextType(),NULL,NULL);
            t->SetLeft(expression);
            expression=t;
            tokenizer.ReadNext();//Eat sign
            TreeNode *right;
            try{ right=ParseTerm(); }//Get second term
            catch(...){ delete expression; throw; }
            expression->SetRight(right);//Set right
        }
        
        return expression;
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

/**
* Parse next term.
* Terms are defined as: Factor { ( * | / ) Factor }
*/
TreeNode* Parser::ParseTerm() throw(SyntaxError)
{
    try
    {
        TreeNode *term=ParseFactor();//Get factor
    
        while(tokenizer.HasNext() &&
              (tokenizer.NextType()==TokenType::TIMES ||
               tokenizer.NextType()==TokenType::DIVIDE))
        {
            term=new TreeNode(tokenizer.NextType(),term,NULL);//Create new node and move old term left
            tokenizer.ReadNext();//Eat sign
            TreeNode *right;
            try{ right=ParseFactor(); }//Get second operand
            catch(...){ delete term; throw; }
            term->SetRight(right);//Set right
        }
    
        return term;//Return term
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

/**
* Parse next factor.
* Factors are defined as: Base [ ^ Sum ]
*/
TreeNode* Parser::ParseFactor() throw(SyntaxError)
{
    try
    {
        TreeNode *base=ParseBase();//Get base
        if(tokenizer.HasNext() &&
           tokenizer.NextType()==TokenType::CARET)
        {
            tokenizer.ReadNext();//Eat carrot
            bool minus=(tokenizer.NextType()==TokenType::MINUS);//Minus sign?
            if(minus)tokenizer.ReadNext();//Eat minus
            TreeNode *exponent;
            try{ exponent=ParseSum(); }//Get number
            catch(...){ delete base; throw; }
            
            if(minus)
            {
                exponent=new TreeNode(TokenType::MINUS,
                                      new TreeNode(TokenType::NUMBER,"0"),
                                      exponent);//Make negative
            }
            return new TreeNode(TokenType::CARET,base,exponent);//Return factor
        }
        else return base;//Return base alone
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

/**
* Parse next base.
* Bases are defined as:
* Number | Variable | HEX | Function ( Sum )
*/
TreeNode* Parser::ParseBase() throw(SyntaxError)
{
    try
    {
        switch(tokenizer.NextType()){
        case TokenType::NUMBER: return ParseValue();
        case TokenType::VARIABLE: return ParseVariable();
        case TokenType::HEX: return ParseHex();
        case TokenType::FUNCTION: return ParseFunction();
        default:
            if(tokenizer.NextType()!=TokenType::LPAREN)
            {
                throw SyntaxError("expected left paren '('");
            }
            tokenizer.ReadNext();//Eat paren
            TreeNode *expression=ParseSum();
            if(tokenizer.NextType()!=TokenType::RPAREN)
            {
                delete expression;
                throw SyntaxError("expected right paren ')'");
            }
            tokenizer.ReadNext();//Eat paren
            return expression;
        }
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

/**
* Parse next function.
* Functions are defined as: Function ( Sum )
*/
TreeNode* Parser::ParseFunction() throw(SyntaxError)
{
    try
    {
        if(tokenizer.NextType()!=TokenType::FUNCTION)throw SyntaxError("expected function");

        string functionName=tokenizer.ReadNext();
        TreeNode *function=new TreeNode(TokenType::FUNCTION,functionName);//Parse and return leaf (value 0 for non-leaf)

        //Invalid syntax - missing paren
        if(!tokenizer.HasNext() ||
           tokenizer.NextType()!=TokenType::LPAREN)
        {
            delete function;
            throw SyntaxError("expected left paren '('");
        }
        tokenizer.ReadNext();//Eat paren
    
        TreeNode *expression;
        try{ expression=ParseSum(); }
        catch(...){ delete function; throw; }
        function->SetRight(expression);

        //Invalid syntax - missing paren
        if(!tokenizer.HasNext() ||
           tokenizer.NextType()!=TokenType::RPAREN)
        {
            delete function;
            delete expression;
            throw SyntaxError("expected right paren ')'");
        }
        tokenizer.ReadNext();//Eat paren
    
        return function;//Return function
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

TreeNode* Parser::ParseValue() throw(SyntaxError)
{
    try
    {
        if(tokenizer.NextType()!=TokenType::VALUE)throw SyntaxError("expected value");
        return new TreeNode(TokenType::VALUE,tokenizer.ReadNext());
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

TreeNode* Parser::ParseVariable() throw(SyntaxError)
{
    try
    {
        if(tokenizer.NextType()!=TokenType::VARIABLE)throw SyntaxError("expected variable");
        return new TreeNode(TokenType::VARIABLE,tokenizer.ReadNext());
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

TreeNode* Parser::ParseHex() throw(SyntaxError)
{
    try
    {
        if(tokenizer.NextType()!=TokenType::HEX)throw SyntaxError("expected value");
        return new TreeNode(TokenType::HEX,tokenizer.ReadNext());
    }
    catch(Tokenizer::UnknownTokenException &e){ throw SyntaxError("unknown token '"+e.GetToken()+"'"); }
    catch(Tokenizer::OutOfBoundsException){ throw(SyntaxError("unexpected end of expression")); }
}

