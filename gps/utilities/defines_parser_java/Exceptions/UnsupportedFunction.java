package Exceptions;

public class UnsupportedFunction extends ExpressionError
{
    private static final long serialVersionUID = 1L;

    public UnsupportedFunction(String function){ super("unsupported function '"+function+"'."); }
};