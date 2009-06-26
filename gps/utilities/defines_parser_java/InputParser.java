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
    public enum FileType { CSV, XML };
    
    private boolean useStdin;
    private String file;
    
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
    
    public int Parse(HashMap<String,MacroEntry> vars,
                     ArrayList<String> verilog)
    {
        return Parse(vars,verilog,true);
    }
    
    public int Parse(HashMap<String,MacroEntry> vars,
                     ArrayList<String> verilog,
                     boolean print)
    {
        if(file.equals("-"))useStdin=true;

        FileType type=FileType.CSV;
        InputStream in;
        if(useStdin)
        {
            in=System.in;
            file="";
        }
        else
        {
            Matcher m=fileName.matcher(file);
            if(m.matches())
            {
                if(m.group(4).equals("xml"))type=FileType.XML;
            }

            try
            {
                in=new FileInputStream(file);
            }
            catch(Exception e)
            {
                InputErrors.PrintWarning("unable to open file '"+file+"', ignoring.");
                return 0;
            }
        }
        BufferedReader inReader=new BufferedReader(new InputStreamReader(in));

        int errorCount;
        try
        {
            switch(type)
            {
            case XML: errorCount=ParseXML(inReader,file,vars,verilog,print); break;
            default: errorCount=ParseCSV(inReader,file,vars,verilog,print); break;
            }
        }
        catch(IOException e)
        {
            InputErrors.PrintError(file,"IO error parsing file.");
            errorCount=1;
        }

        if(!useStdin)
        {
            try
            {
                in.close();
            }
            catch (IOException e)
            {
                InputErrors.PrintWarning("unable to close file '"+file+"'.");
            }
        }

        return errorCount;
    }

    public int ParseCSV(BufferedReader in,
                        String currentFile,
                        HashMap<String,MacroEntry> vars,
                        ArrayList<String> verilog,
                        boolean print) throws IOException
    {
        String line;
        Matcher m;
        int lineCount=0;
        int errorCount=0;
        
        while((line=in.readLine())!=null)
        {
            lineCount++;
            if(comment.matcher(line).matches())continue;
            else if((m=verilogDirective.matcher(line)).matches())
            {
                if(print)verilog.add(m.group(1));
                continue;
            }
            else if((m=directive.matcher(line)).matches())
            {
                errorCount+=EvalDirective(m.group(1),m.group(3),currentFile,lineCount,vars,verilog,print);
                continue;
            }
            else if(!(m=csvLine.matcher(line)).matches())
            {
                InputErrors.PrintError(currentFile,lineCount,"syntax error.");
                errorCount++;
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
                        InputErrors.PrintError(currentFile,lineCount,"undefined variable '"+variable+"'.");
                        errorCount++;
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
                    InputErrors.PrintWarning(currentFile,lineCount,"duplicate declaration of variable '"+variable+
                                             "' in '"+currentPath+"'.\n"+
                                             "originally defined in '"+vars.get(variable).file+
                                             "', line "+String.valueOf(vars.get(variable).line)+".");
                
                MacroEntry entry=new MacroEntry();
                entry.expression=expression;
                entry.print=print;
                entry.file=currentPath;
                entry.line=lineCount;
                if(m.start(4)>=0)
                {
                    String comment=m.group(4);
                    entry.comments=newLine.matcher(comment).replaceAll("\\n");
                }
                vars.put(variable,entry);
            }
            catch(ParserError e)
            {
                e.Embed(true);
                InputErrors.PrintError(currentFile,lineCount,e.getMessage());
                vars.remove(variable);
                errorCount++;
            }
        }

        return errorCount;
    }

    public int ParseXML(BufferedReader in,
                        String currentFile,
                        HashMap<String,MacroEntry> vars,
                        ArrayList<String> verilog,
                        boolean print)
    {
        return 0;
    }

    public int EvalDirective(String directive,
                             String parameter,
                             String currentFile,
                             int currentLine,
                             HashMap<String,MacroEntry> vars,
                             ArrayList<String> verilog,
                             boolean print)
    {
        if(directive.equals("include"))
        {
            Matcher m=Pattern.compile("^(!)?\"([\\/\\w.]+)\"$").matcher(parameter);
            if(!m.matches())
            {
                InputErrors.PrintError(currentFile,
                                       currentLine,
                                       "invalid include directive.");
                return 1;
            }

            if(print)print=m.start(1)<0;
            String file=m.group(2);
            m=fileName.matcher(currentFile);
            if(!m.matches())
            {
                InputErrors.PrintError(currentFile,
                                       currentLine,
                                       "invalid file name \""+currentFile+"\".");
                return 1;
            }
            else if(m.start(2)>=0)file=m.group(2)+file;
            try
            {
                FileInputStream in=new FileInputStream(file);
                in.close();
            }
            catch(Exception e)
            {
                InputErrors.PrintError(currentFile,
                                       currentLine,
                                       "unable to open included file \""+file+"\".");
                return 1;
            }

            InputParser inParser=new InputParser(file);
            int errorCount=inParser.Parse(vars,verilog,print);
            if(errorCount>0)
            {
                InputErrors.PrintError(currentFile,
                                       currentLine,
                                       String.valueOf(errorCount)+" error"+(errorCount>0 ? "s" : "")+" from included file '"+file+"'.");
            }
            return errorCount;
        }
        else
        {
            InputErrors.PrintError(currentFile,
                                   currentLine,
                                   "unknown directive '"+directive+"'.");
            return 1;
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