package OptionsParser;

import java.util.Collections;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.regex.*;

import OptionsParser.Option.OptionType;

public class OptionsParser
{
    private Pattern optionFormat;
    private Pattern singleOption;
    private Pattern multiOption;
    
    public OptionsParser()
    {
        options=new HashMap<String,Option>();
        optionsList=new ArrayList<String>();
        optionFormat=Pattern.compile("^(\\w+(,\\w+)*)(=([ifs]))?$");
        singleOption=Pattern.compile("^(-(\\w+))$");
        multiOption=Pattern.compile("^(--(\\w+))(=(\\w+))?$");
    }
    
    public void AddOption(String option) throws InvalidOptionSyntax,
                                                OptionExistsException
    {
        AddOption(option,"");
    }
    
    public void AddOption(String option, String description) throws InvalidOptionSyntax,
                                                                    OptionExistsException
    {
        Option opt=new Option();
        
        Matcher m=optionFormat.matcher(option);
        if(!m.matches())throw new InvalidOptionSyntax(option);
        
        //Parse option type.
        if(m.start(3)<0)opt.type=OptionType.BOOLEAN;
        else if(m.group(4).equals("i") || m.group(4).equals("f"))opt.type=OptionType.NUMERIC;
        else if(m.group(4).equals("s"))opt.type=OptionType.STRING;
        else opt.type=OptionType.BOOLEAN;
        
        //Parse name string.
        String[] names=m.group(1).split(",");
        String sortName;
        if(names.length>2)throw new InvalidOptionSyntax("expected only two option names");
        else if(names.length==1)
        {
            if(names[0].length()==1)opt.nameString="-"+names[0];
            else opt.nameString="--"+names[0];
            sortName=names[0];
        }
        else
        {
            int single=-1;
            int multi=-1;
            
            if(names[0].length()==1)single=0;
            else multi=0;
            
            if(names[1].length()==1)
            {
                if(single>=0)throw new InvalidOptionSyntax("only one single-character name allowed");
                else single=1;
            }
            else
            {
                if(multi>=0)throw new InvalidOptionSyntax("only one multi-character name allowed");
                else multi=1;
            }
            
            opt.nameString="-"+names[single]+" [ --"+names[multi]+" ]";
            sortName=names[single];
        }
        
        opt.description=description;
        opt.matched=false;
        opt.numericValue=0;
        opt.stringValue="false";
        
        //Add option.
        for (String name : names)
        {
            if(options.containsKey(name))throw new OptionExistsException(name);
            options.put(name,opt);
        }
        optionsList.add(sortName);
    }
    
    public String[] Parse(String[] args) throws UnexpectedOption,
                                                MissingArgument,
                                                UnexpectedArgument,
                                                InvalidArgument,
                                                DuplicateOption
    {
        for(int i=0;i<args.length;i++)
        {
            Matcher m=singleOption.matcher(args[i]);
            if(m.matches())
            {
                //Get option name and accompanying option.
                String name=m.group(2);
                if(!options.containsKey(name))throw new UnexpectedOption(name);
                Option opt=options.get(name);
                args=RemoveOption(args,i);
                
                if(opt.matched)throw new DuplicateOption(name);
                
                //Get argument if necessary.
                if(opt.type==OptionType.BOOLEAN)
                {
                    opt.matched=true;
                    opt.numericValue=1;
                    opt.stringValue="true";
                }
                else
                {
                    if(i==args.length)throw new MissingArgument(name);
                    
                    String value=args[i];
                    args=RemoveOption(args,i);
                    if(opt.type==OptionType.STRING)
                    {
                        opt.matched=true;
                        opt.stringValue=value;
                    }
                    else
                    {
                        try
                        {
                            double doubleValue=Double.parseDouble(value);
                            opt.matched=true;
                            opt.stringValue=value;
                            opt.numericValue=doubleValue;
                        }
                        catch(Exception e)
                        {
                            throw new InvalidArgument(name,value);
                        }
                    }
                }
                
                i--;
                continue;
            }
            
            m=multiOption.matcher(args[i]);
            if(m.matches())
            {
                //Get option name and accompanying option.
                String name=m.group(2);
                if(!options.containsKey(name))throw new UnexpectedOption(name);
                Option opt=options.get(name);
                args=RemoveOption(args,i);
                
                if(opt.matched)throw new DuplicateOption(name);
                
                //Get argument if necessary.
                if(opt.type==OptionType.BOOLEAN)
                {
                    if(m.start(3)<0)
                    {
                        opt.matched=true;
                        opt.numericValue=1;
                        opt.stringValue="true";
                    }
                    else
                    {
                        throw new UnexpectedArgument(name,m.group(4));
                    }
                }
                else
                {
                    if(i==args.length)throw new MissingArgument(name);
                    
                    String value;
                    if(m.start(3)>=0)
                    {
                        value=m.group(4);
                    }
                    else
                    {
                        value=args[i];
                        args=RemoveOption(args,i);
                    }
                    
                    if(opt.type==OptionType.STRING)
                    {
                        opt.matched=true;
                        opt.stringValue=value;
                    }
                    else
                    {
                        try
                        {
                            double doubleValue=Double.parseDouble(value);
                            opt.matched=true;
                            opt.stringValue=value;
                            opt.numericValue=doubleValue;
                        }
                        catch(Exception e)
                        {
                            throw new InvalidArgument(name,value);
                        }
                    }
                }
                
                i--;
                continue;
            }
        }
        
        return args;
    }
    
    public Option Get(String name) throws UnexpectedOption
    {
        if(!options.containsKey(name))throw new UnexpectedOption(name);
        else return options.get(name);
    }
    
    public String toString(){ return ToString(); }
    public String ToString()
    {
        if(optionsList.size()==0)return "";
        
        int maxLength=0;
        for(String name : optionsList)
        {
            Option opt=options.get(name);
            if(opt.nameString.length()>maxLength)
            {
                maxLength=opt.nameString.length();
            }
        }

        String string="";
        Collections.sort(optionsList);
        for(String name : optionsList)
        {
            Option opt=options.get(name);
            string+="   "+opt.nameString;
            for(int i=0;i<maxLength-opt.nameString.length();i++)string+=" ";
            string+=" "+opt.description+"\n";
        }
        
        return string;
    }
    
    private String[] RemoveOption(String[] args, int index)
    {
        if(index>args.length-1)return args;
        else if(args.length==1)return new String[0];
        else
        {
            String[] result=new String[args.length-1];
            if(index>0)System.arraycopy(args,0,result,0,index);
            if(index+1<args.length)System.arraycopy(args,index+1,result,index,args.length-index-1);
            return result;
        }
    }
    
    private HashMap<String,Option> options;
    private ArrayList<String> optionsList;
}
