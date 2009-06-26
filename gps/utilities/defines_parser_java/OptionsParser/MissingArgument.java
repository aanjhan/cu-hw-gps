package OptionsParser;

public class MissingArgument extends Exception
{
    private static final long serialVersionUID = 1L;

    public MissingArgument(String option)
    {
        super("missing argument for option '"+option+"'");
    }
}