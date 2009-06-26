import java.util.regex.*;
import Exceptions.UnknownTokenException;

public class Tokenizer
{
    public class TokenType
    {
        static final int COLON     = 1;
        static final int CONST     = 2;
        static final int PLUS      = 3;
        static final int MINUS     = 4;
        static final int TIMES     = 5;
        static final int DIVIDE    = 6;
        static final int CARET     = 7;
        static final int LPAREN    = 8;
        static final int RPAREN    = 9;
        static final int FUNCTION  = 10;
        static final int VARIABLE  = 11;
        static final int VALUE     = 12;
        static final int NUMBER    = 12;
        static final int HEX       = 13;
        static final int SEMICOLON = 14;
        static final int AT        = 15;
        static final int ILLEGAL   = 16;
    }
    
    private static final Pattern verilogConstant = Pattern.compile("^('[dhb])");
    private static final Pattern hexValue = Pattern.compile("^(\\d+[A-Fa-f][A-Fa-f0-9]*)");
    private static final Pattern number = Pattern.compile("^(\\d+(\\.\\d+)?(e-?\\d+)?)");
    private static final Pattern qualifiedName = Pattern.compile("^(`?[A-Za-z_]\\w*)");
    
    private String expression;
    
    public Tokenizer(String expression)
    {
        this.expression=expression;
    }
    
    public boolean HasNext()
    {
        return expression.length()!=0;
    }

    public int NextType() throws UnknownTokenException,IndexOutOfBoundsException
    {
        Matcher m;

        if(!HasNext())throw new IndexOutOfBoundsException();

        //Is this a qualified name (variable or function)?
        if((m=qualifiedName.matcher(expression)).lookingAt())
        {
            if(expression.length()>m.group(1).length() &&
               expression.charAt(m.group(1).length())=='(')
                return TokenType.FUNCTION;
            else return TokenType.VARIABLE;
        }
        //Is this a hex value?
        else if((m=hexValue.matcher(expression)).lookingAt())
        {
            return TokenType.HEX;
        }
        //Is this a number?
        else if((m=number.matcher(expression)).lookingAt())
        {
            return TokenType.NUMBER;
        }
        //Is this a Verilog constant?
        else if((m=verilogConstant.matcher(expression)).lookingAt())
        {
            return TokenType.CONST;
        }
        else
        {
            switch(expression.charAt(0))
            {
            case ':': return TokenType.COLON;
            case '+': return TokenType.PLUS;
            case '-': return TokenType.MINUS;
            case '*': return TokenType.TIMES;
            case '/': return TokenType.DIVIDE;
            case '^': return TokenType.CARET;
            case '(': return TokenType.LPAREN;
            case ')': return TokenType.RPAREN;
            case ';': return TokenType.SEMICOLON;
            case '@': return TokenType.AT;
            default: throw new UnknownTokenException(expression.substring(0,1));
            }
        }
    }

    public String ReadNext() throws IndexOutOfBoundsException
    {
        Matcher m;

        if(expression.length()==0)throw new IndexOutOfBoundsException();

        //Is this a number of qualified name (variable or function)?
        if((m=qualifiedName.matcher(expression)).lookingAt() ||
           (m=hexValue.matcher(expression)).lookingAt() ||
           (m=number.matcher(expression)).lookingAt() ||
           (m=verilogConstant.matcher(expression)).lookingAt())
        {
            String s=m.group(1);
            try{ expression=expression.substring(s.length()); }
            catch(IndexOutOfBoundsException e){}
            return s;
        }
        else
        {
            String s=expression.substring(0,1);
            try{ expression=expression.substring(1); }
            catch(IndexOutOfBoundsException e){}
            return s;
        }
    }
}
