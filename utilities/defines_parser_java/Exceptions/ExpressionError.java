package Exceptions;

public class ExpressionError extends Exception
{
    private static final long serialVersionUID = 1L;
    
    protected boolean embed;
    protected String variable;
    protected String message;
    
    public ExpressionError(String message)
    {
        this("",message);
    }
    
    public ExpressionError(String variable,String message)
    {
            this.variable=variable;
            this.message=message;
            embed=false;
    }

    public void Embed(boolean embed){ this.embed=embed; }
    public void SetVariable(String variable){ this.variable=variable; }
    public void SetMessage(String message){ this.message=message; }
        
    public String getMessage()
    {
        String out="";
        if(!embed)
        {
            out="Error";
            if(!variable.equals(""))out+="("+variable+")";
            out+=": ";
        }
        else if(!variable.equals(""))out+="("+variable+") : ";
        out+=message;
        return out;
    }
}