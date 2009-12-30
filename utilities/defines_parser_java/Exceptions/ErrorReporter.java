package Exceptions;

import java.util.ArrayList;

public class ErrorReporter
{
    public enum ErrorType { ERROR, WARNING, INFO };
    
    private static int errorCount=0;
    private static int warningCount=0;
    private static ArrayList<String> report=new ArrayList<String>();
    
    private static ErrorType currentType;
    private static String currentFile;
    private static int currentLine;
    private static String currentMessage;
    
    public static int ErrorCount(){ return errorCount; }
    public static int WarningCount(){ return warningCount; }
    public static int ReportSize(){ return errorCount+warningCount; }
    public static String Report()
    {
    	String reportString="";
    	for(String entry : report)reportString+=entry+"\n";
    	return reportString;
    }
    public static String Summary()
    {
    	String summary="Found ";
    	
    	if(ReportSize()==0)return "";
		
		if(errorCount>0)
		{
			summary+=String.valueOf(errorCount)+" error";
			if(errorCount>1)summary+="s";
		}
		
		if(warningCount>0)
		{
			if(errorCount>0)summary+=", ";
			summary+=String.valueOf(warningCount)+" warning";
			if(warningCount>1)summary+="s";
		}
		
		summary+=".\n";
		
		return summary;
    }
    
    public static void Warning(String file,int line,String message)
    {
    	currentType=ErrorType.WARNING;
    	currentFile=file;
    	currentLine=line;
    	currentMessage=message;
    	InsertMessage();
    	warningCount++;
    }
    public static void Warning(String file,
                             String message){ Warning(file,0,message); }
    public static void Warning(String message){ Warning("",0,message); }

    public static void Error(String file,int line,String message)
    {
    	currentType=ErrorType.ERROR;
    	currentFile=file;
    	currentLine=line;
    	currentMessage=message;
    	InsertMessage();
    	errorCount++;
    }
    public static void Error(String file,
                           String message){ Error(file,0,message); }
    public static void Error(String message){ Error("",0,message); }

    public static void SetType(ErrorType type)
    {
    	currentType=type;
    	UpdateMessage();
    }
    public static void SetFile(String file)
    {
    	currentFile=file;
    	UpdateMessage();
    }
    public static void SetLine(int line)
    {
    	currentLine=line;
    	UpdateMessage();
    }
    public static void SetMessage(String message)
    {
    	currentMessage=message;
    	UpdateMessage();
    }
    public static void AppendFront(String message)
    {
    	currentMessage=message+currentMessage;
    	UpdateMessage();
    }
    public static void AppendBack(String message)
    {
    	currentMessage=currentMessage+message;
    	UpdateMessage();
    }
    
    private static void InsertMessage()
    {
    	report.add("");
    	UpdateMessage();
    }
    
    private static void UpdateMessage()
    {
    	if(report.size()==0)return;
    	report.set(report.size()-1, ErrorString(currentType,currentFile,currentLine,currentMessage));
    }
    
    private static String ErrorString(ErrorType type,
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