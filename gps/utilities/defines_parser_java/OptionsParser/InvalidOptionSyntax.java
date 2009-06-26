package OptionsParser;

public class InvalidOptionSyntax extends Exception
{
    private static final long serialVersionUID = 1L;

    public InvalidOptionSyntax(String option)
    {
        super("invalid option syntax: "+option);
    }
}