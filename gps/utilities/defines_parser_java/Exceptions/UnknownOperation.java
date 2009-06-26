package Exceptions;

public class UnknownOperation extends ExpressionError
{
    private static final long serialVersionUID = 1L;

    public UnknownOperation(int type){ super("unknown operation type "+String.valueOf(type)+"."); }
};