package OptionsParser;

public class OptionExistsException extends Exception
{
    private static final long serialVersionUID = 1L;

    public OptionExistsException(String option)
    {
        super("option '"+option+"' already exists");
    }
}