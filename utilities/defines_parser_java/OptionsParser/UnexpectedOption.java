package OptionsParser;

public class UnexpectedOption extends Exception
{
    private static final long serialVersionUID = 1L;

    public UnexpectedOption(String option)
    {
        super("unexpected option '"+option+"'");
    }
}