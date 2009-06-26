package Exceptions;

public class UnknownTokenException extends Exception
{
    private static final long serialVersionUID = 1L;
    private String token;
    
    public UnknownTokenException(String token)
    {
        super("Unknown token '"+token+"'");
        this.token=token;
    }
    public String GetToken(){ return token; }
};