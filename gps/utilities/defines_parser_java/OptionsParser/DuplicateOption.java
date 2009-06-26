package OptionsParser;

public class DuplicateOption extends Exception
{
    private static final long serialVersionUID = 1L;

    public DuplicateOption(String option)
    {
        super("duplicate option '"+option+"' received");
    }
}