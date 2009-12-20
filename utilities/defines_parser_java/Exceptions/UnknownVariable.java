package Exceptions;

public class UnknownVariable extends ExpressionError
{
    private static final long serialVersionUID = 1L;

    public UnknownVariable(String var){ super("unknown variable '"+var+"'."); }
};