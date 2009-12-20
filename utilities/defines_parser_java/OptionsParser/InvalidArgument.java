package OptionsParser;

public class InvalidArgument extends Exception
{
    private static final long serialVersionUID = 1L;

    public InvalidArgument(String option,String value)
    {
        super("invalid argument value '"+value+"' for option '"+option+"'");
    }
}