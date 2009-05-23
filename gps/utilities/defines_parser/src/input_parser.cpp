#include <iostream>
#include <fstream>
#include <algorithm>
#include "input_parser.h"

using namespace std;

const boost::regex InputParser::fileName("^((.*\\/)?([^\\/]*))\\.([^.]+)$");
const boost::regex InputParser::comment("^ *(//.*)?$");
const boost::regex InputParser::directive("^#(\\w+)( (.*))?$");
const boost::regex InputParser::csvLine("^([A-Za-z_]\\w*),([^,]*)(,(.*))?$");
const boost::regex InputParser::newLine("\\\\n");

void InputParser::Parse(map<string,MacroEntry*> &vars, bool print) throw(Error)
{
    map<string,MacroEntry*> tempVars;

    if(file=="-")useStdin=true;

    FileType type=CSV;
    ifstream inFile;
    istream *in;
    if(useStdin)
    {
        in=&cin;
        file="";
    }
    else
    {
        boost::smatch m;
        if(boost::regex_match(file,m,fileName))
        {
            if(m[4]=="xml")type=XML;
        }
        
        inFile.open(file.c_str());
        if(!inFile.good())throw Warning("unable to open file '"+file+"', ignoring.");
        in=&inFile;
    }

    try
    {
        switch(type)
        {
        case XML: ParseXML(*in,file,tempVars,print); break;
        default: ParseCSV(*in,file,tempVars,print); break;
        }
    }
    catch(Error &e)
    {
        for(map<string,MacroEntry*>::iterator i=tempVars.begin();
            i!=tempVars.end();
            i++)
        {
            delete (*i).second;
        }
        
        if(!useStdin)
        {
            inFile.close();
            e.SetFile(file);
        }
        
        throw e;
    }

    if(!useStdin)
    {
        inFile.close();
    }

    copy(tempVars.begin(),tempVars.end(),inserter(vars,vars.end()));
}

void InputParser::ParseCSV(std::istream &in,
                           const std::string &currentFile,
                           std::map<std::string,MacroEntry*> &vars,
                           bool print) throw(Error)
{
    string line;
    boost::smatch m;
    int lineCount=0;
    while(!in.eof())
    {
        lineCount++;
        getline(in,line);
        if(boost::regex_match(line,comment))continue;
        else if(boost::regex_match(line,m,directive))
        {
            try
            {
                EvalDirective(m[1],m[3],currentFile,lineCount,vars);
            }
            catch(Error &e)
            {
                cout<<e.what()<<endl;
            }
            continue;
        }
        else if(!boost::regex_match(line,m,csvLine))
        {
            Error::PrintError(currentFile,lineCount,"syntax error, ignoring entry.");
            continue;
        }

        string variable=m[1];
        if(vars.find(variable)!=vars.end())
            Error::PrintWarning(currentFile,lineCount,"duplicate declaration of variable '"+variable+"'.");
        
        try
        {
            vars[variable]=new MacroEntry();
            vars[variable]->expression=new Expression(m[2]);
            vars[variable]->print=print;
            if(m[4].matched)
            {
                string comment=m[4];
                vars[variable]->comments=boost::regex_replace(comment,newLine,"\\n");
            }
        }
        catch(...)
        {
            Error::PrintError(currentFile,lineCount,"syntax error in expression.");
            delete vars[variable];
            vars.erase(variable);
        }
    }
}

void InputParser::ParseXML(std::istream &in,
                           const std::string &currentFile,
                           std::map<std::string,MacroEntry*> &vars,
                           bool print) throw(Error)
{
}

void InputParser::EvalDirective(const std::string &directive,
                                const std::string &parameter,
                                const std::string &currentFile,
                                int currentLine,
                                std::map<std::string,MacroEntry*> &vars,
                                bool print) throw(Error)
{
    if(directive=="include")
    {
        boost::smatch m;
        if(!boost::regex_match(parameter,m,boost::regex("^(!)?\"([\\w.]+)\"$")))
            throw Error(currentFile,currentLine,"invalid include directive.");

        if(print)print=!m[1].matched;
        string file=m[2];
        boost::regex_match(currentFile,m,fileName);
        if(m[2].matched)file=m[2]+file;
        ifstream in(file.c_str());
        if(!in.good())throw Error(currentFile,currentLine,"unable to open included file \""+file+"\".");
        in.close();

        try
        {
            InputParser in(file);
            in.Parse(vars,print);
        }
        catch(Error &e)
        {
            e.SetMessage(string("included here.\n")+e.what());
            e.SetLine(currentLine);
            e.SetFile(currentFile);
            throw e;
        }
    }
    else throw Error(currentFile,currentLine,"unknown directive '"+directive+"'.");
}

void InputParser::Error::PrintWarning(const std::string &file,int line,const std::string &message)
{
    cout<<ErrorString(WARNING,file,line,message)<<endl;
}

void InputParser::Error::PrintError(const std::string &file,int line,const std::string &message)
{
    cout<<ErrorString(ERROR,file,line,message)<<endl;
}

std::string InputParser::Error::ErrorString(ErrorType type,
                                            const std::string &file,
                                            int line,
                                            const std::string &message)
{
    string out;

    switch(type)
    {
    case ERROR: out="Error: "; break;
    case WARNING: out="Warning: "; break;
    default: out="Info: "; break;
    }
    
    out+=message;
    if(file!="")out=file+(line>0 ? "("+StringHelper::ToString(line)+")" : "")+": "+out;
    return out;
}
