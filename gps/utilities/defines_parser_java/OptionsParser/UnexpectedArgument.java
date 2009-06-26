package OptionsParser;

public class UnexpectedArgument extends Exception
{
    private static final long serialVersionUID = 1L;

    public UnexpectedArgument(String option,String value)
    {
        super("unexpected argument value '"+value+"' for option '"+option+"'");
    }
}