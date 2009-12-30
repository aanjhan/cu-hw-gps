import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.regex.*;
import java.util.HashMap;
import java.util.ArrayList;
import java.net.URI;
import java.net.URISyntaxException;

import Exceptions.*;

public class InputParser
{
    public enum InputType { CSV, XML };
    public enum Directive { INCLUDE, UNKNOWN };
    
    private boolean useStdin;
    private InputStream inStream;
    private String file;
    private InputType type;
    
    private static final Pattern fileName = Pattern.compile("^((.*\\/)?([^\\/]*))\\.([^.]+)$");
    private static final Pattern comment = Pattern.compile("^ *(//.*)?$");
    private static final Pattern directive = Pattern.compile("^ *# *(\\w+)( (.*))?$");
    private static final Pattern verilogDirective = Pattern.compile("^( *`\\w+( (.*))?)$");
    private static final Pattern csvLine = Pattern.compile("^ *([A-Za-z_]\\w*) *,([^,]*)(,(.*))?$");
    private static final Pattern newLine = Pattern.compile("\\\\n");
    
    public InputParser()
    {
        useStdin=true;
        file="";
    }
    
    public InputParser(String file)
    {
        useStdin=false;
        this.file=file;
    }
    
    private BufferedReader OpenStream(){ return OpenStream(false); }
    private BufferedReader OpenStream(boolean errorOnFail)
    {
        if(file.equals("-"))useStdin=true;

        type=InputType.CSV;
        if(useStdin)
        {
            inStream=System.in;
            file="";
        }
        else
        {
            Matcher m=fileName.matcher(file);
            if(m.matches())
            {
                if(m.group(4).equals("xml"))type=InputType.XML;
            }

            try
            {
                inStream=new FileInputStream(file);
            }
            catch(Exception e)
            {
                if(errorOnFail)ErrorReporter.Error("unable to open file '"+file+"'.");
                else ErrorReporter.Warning("unable to open file '"+file+"'.");
                return null;
            }
        }
        
        return new BufferedReader(new InputStreamReader(inStream));
    }
    
    private void Cleanup()
    {
        if(!useStdin)
        {
            try
            {
                inStream.close();
            }
            catch (IOException e)
            {
                ErrorReporter.Warning("unable to close file '"+file+"'.");
            }
        }
    }
    
    public int Parse(HashMap<String,MacroEntry> vars,
                     ArrayList<String> verilog)
    {
        return Parse(vars,verilog,true);
    }
    
    public int Parse(HashMap<String,MacroEntry> vars,
                     ArrayList<String> verilog,
                     boolean print)
    {
        BufferedReader inReader=OpenStream(false);
        
        if(inReader!=null)
        {
        	try
        	{
        		switch(type)
        		{
        		case XML: ParseXML(inReader,file,vars,verilog,print); break;
        		default: ParseCSV(inReader,file,vars,verilog,print); break;
        		}
        	}
        	catch(IOException e)
        	{
        		ErrorReporter.Error(file,"IO error parsing file.");
        	}
        }
        
        Cleanup();

        return ErrorReporter.ErrorCount();
    }

    public void ParseCSV(BufferedReader in,
                        String currentFile,
                        HashMap<String,MacroEntry> vars,
                        ArrayList<String> verilog,
                        boolean print) throws IOException
    {
        String line;
        Matcher m;
        int lineCount=0;
        
        while((line=in.readLine())!=null)
        {
            lineCount++;
            if(comment.matcher(line).matches())continue;
            else if((m=directive.matcher(line)).matches())
            {
                ExecDirective(m.group(1),m.group(3),currentFile,lineCount,vars,verilog,print);
                continue;
            }
            else if((m=verilogDirective.matcher(line)).matches())
            {
                if(print)verilog.add(m.group(1));
                continue;
            }
            else if(!(m=csvLine.matcher(line)).matches())
            {
                ErrorReporter.Error(currentFile,lineCount,"unrecognized input format.");
                continue;
            }
            
            String variable=m.group(1);
            try
            {
                Expression expression=new Expression(m.group(2));

                if(expression.IsReprint())
                {
                    if(!vars.containsKey(variable))
                    {
                        ErrorReporter.Error(currentFile,lineCount,"undefined variable '"+variable+"'.");
                    }
                    else if(!vars.get(variable).print)vars.get(variable).print=print;
                    continue;
                }
                
                String currentPath="";
                try
                {
                    currentPath = (new URI((new File(currentFile)).getAbsolutePath())).normalize().toString();
                }
                catch (URISyntaxException e){}
                if(vars.containsKey(variable) &&
                   (!FileCompare(currentPath,vars.get(variable).file) ||
                    vars.get(variable).line!=lineCount))
                {
                    ErrorReporter.Warning(currentFile,lineCount,"duplicate declaration of variable '"+variable+
                                             "' in '"+currentPath+"'.\n"+
                                             "originally defined in '"+vars.get(variable).file+
                                             "', line "+String.valueOf(vars.get(variable).line)+".");
                }
                
                MacroEntry entry=new MacroEntry();
                entry.expression=expression;
                entry.print=print;
                entry.file=currentPath;
                entry.line=lineCount;
                if(m.start(4)>=0)
                {
                    String comment=m.group(4);
                    entry.comments=newLine.matcher(comment).replaceAll("\n");
                }
                vars.put(variable,entry);
            }
            catch(ParserError e)
            {
                e.Embed(true);
                ErrorReporter.Error(currentFile,lineCount,e.getMessage());
                vars.remove(variable);
            }
        }
    }

    public void ParseXML(BufferedReader in,
                        String currentFile,
                        HashMap<String,MacroEntry> vars,
                        ArrayList<String> verilog,
                        boolean print)
    {
        ErrorReporter.Error("XML files currently unsupported.");
    }
    
    public ArrayList<String> ListDependencies()
    {
        BufferedReader inReader=OpenStream(false);
        
        if(inReader==null)return null;
        
        ArrayList<String> deps=new ArrayList<String>();
        String line;
        Matcher m;
        int lineCount=0;
        try
        {
        	while((line=inReader.readLine())!=null)
        	{
        		lineCount++;
        		
        		if(comment.matcher(line).matches())continue;
        		else if((m=directive.matcher(line)).matches())
        		{
        			if(EvalDirective(m.group(1),m.group(3))==Directive.INCLUDE);

                    m=Pattern.compile("^(!)?\"([\\/\\w.]+)\"$").matcher(m.group(3));
                    if(!m.matches())
                    {
                        ErrorReporter.Warning(file,
                        		lineCount,
                                               "invalid include directive.");
                    }
                    else deps.add(m.group(2));
        			continue;
        		}
        	}
        }
        catch(IOException e)
        {
        	ErrorReporter.Error(e.getMessage());
        }
        
        Cleanup();
        
    	return deps;
    }

    public Directive EvalDirective(String directive, String parameter)
    {
        if(directive.equals("include"))return Directive.INCLUDE;
        else return Directive.UNKNOWN;
    }

    public void ExecDirective(String directive,
                             String parameter,
                             String currentFile,
                             int currentLine,
                             HashMap<String,MacroEntry> vars,
                             ArrayList<String> verilog,
                             boolean print)
    {
    	Directive dir=EvalDirective(directive,parameter);
        if(dir==Directive.INCLUDE)
        {
            Matcher m=Pattern.compile("^(!)?\"([\\/\\w.]+)\"$").matcher(parameter);
            if(!m.matches())
            {
                ErrorReporter.Error(currentFile,
                                       currentLine,
                                       "invalid include directive.");
                return;
            }

            if(print)print=m.start(1)<0;
            String file=m.group(2);
            m=fileName.matcher(currentFile);
            if(!m.matches())
            {
                ErrorReporter.Error(currentFile,
                                       currentLine,
                                       "invalid file name \""+currentFile+"\".");
                return;
            }
            else if(m.start(2)>=0)file=m.group(2)+file;
            try
            {
                FileInputStream in=new FileInputStream(file);
                in.close();
            }
            catch(Exception e)
            {
                ErrorReporter.Error(currentFile,
                                       currentLine,
                                       "unable to open included file \""+file+"\".");
                return;
            }

            int errorCount=ErrorReporter.ErrorCount();
            InputParser inParser=new InputParser(file);
            inParser.Parse(vars,verilog,print);
            errorCount=ErrorReporter.ErrorCount()-errorCount;
            if(errorCount>0)
            {
                ErrorReporter.Error(currentFile,
                                       currentLine,
                                       String.valueOf(errorCount)+" error"+(errorCount>0 ? "s" : "")+" from included file '"+file+"'.");
            }
        }
        else
        {
            ErrorReporter.Error(currentFile,
                                   currentLine,
                                   "unknown directive '"+directive+"'.");
        }
    }
    
    private boolean FileCompare(String file1, String file2)
    {
        try
        {
            file1=(new File(file1)).getCanonicalPath();
            file2=(new File(file2)).getCanonicalPath();
            return file1.equals(file2);
        }
        catch (IOException e){ return false; }
    }
}