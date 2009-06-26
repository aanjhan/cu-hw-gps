package Exceptions;

public class ParserError extends Exception
{
    private static final long serialVersionUID = 1L;
    
    protected boolean embed;
    protected String message;
    
    public ParserError(String message)
    {
        this.message=message+".";
        embed=false;
    }

    public void Embed(boolean embed){ this.embed=embed; }
        
    public String getMessage()
    {
        String out="";
        if(!embed)
        {
            out="Parser error: ";
        }
        else out="parser error : ";
        out+=message;
        return out;
    }
}