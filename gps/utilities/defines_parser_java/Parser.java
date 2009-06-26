import Exceptions.ParserError;
import Exceptions.SyntaxError;
import Exceptions.UnknownTokenException;

public class Parser
{
    Tokenizer tokenizer;
    
    public Parser(String expression)
    {
        tokenizer=new Tokenizer(expression);
    }
    
    public static TreeNode Parse(String expression) throws ParserError
    {
        return (new Parser(expression)).Parse();
    }

    public TreeNode Parse() throws ParserError
    {
        TreeNode expression=ParseExpression();
        if(tokenizer.HasNext())throw new ParserError("characters remaining in expression");
        return expression;
    }

    /**
    * Parse next expression.
    * Expressions are defined as: @ | Sum [ : Sum | '[hdb] Expression ]
    */
    public TreeNode ParseExpression() throws SyntaxError
    {
        try
        {
            if(tokenizer.HasNext() && tokenizer.NextType()==Tokenizer.TokenType.AT)
            {
                tokenizer.ReadNext();
                return new TreeNode(Tokenizer.TokenType.AT,null,null);
            }
        }
        catch(UnknownTokenException e)
        {
            throw new SyntaxError(e.getMessage());
        }
        
        //Read range.
        TreeNode expression=ParseSum();

        try
        {
            if(tokenizer.HasNext())
            {
                if(tokenizer.NextType()==Tokenizer.TokenType.COLON)
                {
                    tokenizer.ReadNext();
                    expression=new TreeNode(Tokenizer.TokenType.COLON,expression,null);

                    TreeNode right;
                    right=ParseSum();//Get second term
                    expression.SetRight(right);
                }
                else if(tokenizer.NextType()==Tokenizer.TokenType.CONST)
                {
                    expression=new TreeNode(Tokenizer.TokenType.CONST,expression,null);
                    expression.SetValue(tokenizer.ReadNext());
            
                    TreeNode right;
                    right=ParseSum();//Get second term
                    expression.SetRight(right);
                }
            }
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
        
        return expression;
    }

    /**
    * Parse next sum.
    * Sums are defined as: [-] Term { (+ | -) Term }
    */
    public TreeNode ParseSum() throws SyntaxError
    {
        try
        {
            //Read initial minus sign.
            boolean minus=(tokenizer.NextType()==Tokenizer.TokenType.MINUS);
            if(minus)tokenizer.ReadNext();

            TreeNode expression=ParseTerm();//Get term
        
            if(minus)expression=new TreeNode(Tokenizer.TokenType.MINUS,new TreeNode(Tokenizer.TokenType.NUMBER,"0"),expression);//Make negative
        
            while(tokenizer.HasNext() &&
                  (tokenizer.NextType()==Tokenizer.TokenType.PLUS ||
                   tokenizer.NextType()==Tokenizer.TokenType.MINUS))
            {
                TreeNode t=new TreeNode(tokenizer.NextType(),null,null);
                t.SetLeft(expression);
                expression=t;
                tokenizer.ReadNext();//Eat sign
                TreeNode right;
                right=ParseTerm();//Get second term
                expression.SetRight(right);
            }
            
            return expression;
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    /**
    * Parse next term.
    * Terms are defined as: Factor { ( * | / ) Factor }
    */
    public TreeNode ParseTerm() throws SyntaxError
    {
        try
        {
            TreeNode term=ParseFactor();//Get factor
        
            while(tokenizer.HasNext() &&
                  (tokenizer.NextType()==Tokenizer.TokenType.TIMES ||
                   tokenizer.NextType()==Tokenizer.TokenType.DIVIDE))
            {
                term=new TreeNode(tokenizer.NextType(),term,null);//Create new node and move old term left
                tokenizer.ReadNext();//Eat sign
                TreeNode right;
                right=ParseFactor();//Get second operand
                term.SetRight(right);//Set right
            }
        
            return term;//Return term
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    /**
    * Parse next factor.
    * Factors are defined as: Base [ ^ Sum ]
    */
    public TreeNode ParseFactor() throws SyntaxError
    {
        try
        {
            TreeNode base=ParseBase();//Get base
            if(tokenizer.HasNext() &&
               tokenizer.NextType()==Tokenizer.TokenType.CARET)
            {
                tokenizer.ReadNext();//Eat carrot
                boolean minus=(tokenizer.NextType()==Tokenizer.TokenType.MINUS);//Minus sign?
                if(minus)tokenizer.ReadNext();//Eat minus
                TreeNode exponent;
                exponent=ParseSum();//Get number
                
                if(minus)
                {
                    exponent=new TreeNode(Tokenizer.TokenType.MINUS,
                                          new TreeNode(Tokenizer.TokenType.NUMBER,"0"),
                                          exponent);//Make negative
                }
                return new TreeNode(Tokenizer.TokenType.CARET,base,exponent);//Return factor
            }
            else return base;//Return base alone
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    /**
    * Parse next base.
    * Bases are defined as:
    * Number | Variable | HEX | Function ( Sum [; Sum]... )
    */
    public TreeNode ParseBase() throws SyntaxError
    {
        try
        {
            switch(tokenizer.NextType()){
            case Tokenizer.TokenType.NUMBER: return ParseValue();
            case Tokenizer.TokenType.VARIABLE: return ParseVariable();
            case Tokenizer.TokenType.HEX: return ParseHex();
            case Tokenizer.TokenType.FUNCTION: return ParseFunction();
            default:
                if(tokenizer.NextType()!=Tokenizer.TokenType.LPAREN)
                {
                    throw new SyntaxError("expected left paren '('");
                }
                tokenizer.ReadNext();//Eat paren
                TreeNode expression=ParseSum();
                if(tokenizer.NextType()!=Tokenizer.TokenType.RPAREN)
                {
                    throw new SyntaxError("expected right paren ')'");
                }
                tokenizer.ReadNext();//Eat paren
                return expression;
            }
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    /**
    * Parse next function.
    * Functions are defined as: Function ( Sum [; Sum]... )
    */
    public TreeNode ParseFunction() throws SyntaxError
    {
        try
        {
            if(tokenizer.NextType()!=Tokenizer.TokenType.FUNCTION)throw new SyntaxError("expected function");

            String functionName=tokenizer.ReadNext();
            TreeNode function=new TreeNode(Tokenizer.TokenType.FUNCTION,functionName);//Parse and return leaf (value 0 for non-leaf)

            //Invalid syntax - missing paren
            if(!tokenizer.HasNext() ||
               tokenizer.NextType()!=Tokenizer.TokenType.LPAREN)
            {
                throw new SyntaxError("expected left paren '('");
            }
            tokenizer.ReadNext();//Eat paren
        
            TreeNode expression;
            expression=ParseSum();
            function.SetRight(expression);

            TreeNode parent=function;
            while(tokenizer.HasNext() &&
                  (tokenizer.NextType()==Tokenizer.TokenType.SEMICOLON))
            {
                tokenizer.ReadNext();
                parent.SetRight(new TreeNode(Tokenizer.TokenType.SEMICOLON,
                                             parent.GetRight(),
                                             null));
                parent=parent.GetRight();
                parent.SetRight(ParseSum());
            }

            //Invalid syntax - missing paren
            if(!tokenizer.HasNext() ||
               tokenizer.NextType()!=Tokenizer.TokenType.RPAREN)
            {
                throw new SyntaxError("expected right paren ')'");
            }
            tokenizer.ReadNext();//Eat paren
        
            return function;//Return function
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    public TreeNode ParseValue() throws SyntaxError
    {
        try
        {
            if(tokenizer.NextType()!=Tokenizer.TokenType.VALUE)throw new SyntaxError("expected value");
            return new TreeNode(Tokenizer.TokenType.VALUE,tokenizer.ReadNext());
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    public TreeNode ParseVariable() throws SyntaxError
    {
        try
        {
            if(tokenizer.NextType()!=Tokenizer.TokenType.VARIABLE)throw new SyntaxError("expected variable");
            return new TreeNode(Tokenizer.TokenType.VARIABLE,tokenizer.ReadNext());
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }

    public TreeNode ParseHex() throws SyntaxError
    {
        try
        {
            if(tokenizer.NextType()!=Tokenizer.TokenType.HEX)throw new SyntaxError("expected value");
            return new TreeNode(Tokenizer.TokenType.HEX,tokenizer.ReadNext());
        }
        catch(UnknownTokenException e){ throw new SyntaxError("unknown token '"+e.GetToken()+"'"); }
        catch(IndexOutOfBoundsException e){ throw new SyntaxError("unexpected end of expression"); }
    }
}