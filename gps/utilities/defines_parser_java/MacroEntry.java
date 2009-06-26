class MacroEntry
{
    public String file;
    public int line;
    
    public boolean print;
    public Expression expression;
    public String comments;

    MacroEntry()
    {
        print=false;
        expression=null;
        comments="";
    }
};