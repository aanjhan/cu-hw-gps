package Exceptions;

public class SyntaxError extends ParserError
{
    private static final long serialVersionUID = 1L;

    public SyntaxError(){ super("syntax error"); }
    public SyntaxError(String error){ super(error); }
};