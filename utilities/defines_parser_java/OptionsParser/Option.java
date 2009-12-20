package OptionsParser;

public class Option
{
    public enum OptionType { BOOLEAN, NUMERIC, STRING }
    
    public String nameString;
    public String description;
    public boolean matched;
    
    public String stringValue;
    public double numericValue;

    OptionType type;
}