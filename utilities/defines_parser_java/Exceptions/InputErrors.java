package Exceptions;

public class InputErrors
{
    public enum ErrorType { ERROR, WARNING, INFO };
    
    public static void PrintWarning(String file,int line,String message)
    {
        System.err.println(ErrorString(ErrorType.WARNING,file,line,message));
    }
    public static void PrintWarning(String file,
                             String message){ PrintWarning(file,0,message); }
    public static void PrintWarning(String message){ PrintWarning("",0,message); }

    public static void PrintError(String file,int line,String message)
    {
        System.err.println(ErrorString(ErrorType.ERROR,file,line,message));
    }
    public static void PrintError(String file,
                           String message){ PrintError(file,0,message); }
    public static void PrintError(String message){ PrintError("",0,message); }
    
    public static String ErrorString(ErrorType type,
                                     String file,
                                     int line,
                                     String message)
    {
        String header;
        String out;

        switch(type)
        {
        case ERROR: header="Error: "; break;
        case WARNING: header="Warning: "; break;
        default: header="Info: "; break;
        }
        if(file!="")header=file+(line>0 ? "("+String.valueOf(line)+")" : "")+": "+header;

        String spaces="\n";
        for(int i=0;i<header.length();i++)spaces+=" ";
        out=message.replaceAll("\\n",spaces);
        
        return header+out;
    }
};