#include <iostream>
#include <fstream>
#include <algorithm>
#include "input_parser.h"
#include "string_helper.hpp"

using namespace std;
using namespace StringHelper;

const boost::regex InputParser::fileName("^((.*\\/)?([^\\/]*))\\.([^.]+)$");
const boost::regex InputParser::comment("^ *(//.*)?$");
const boost::regex InputParser::directive("^ *# *(\\w+)( (.*))?$");
const boost::regex InputParser::csvLine("^ *([A-Za-z_]\\w*) *,([^,]*)(,(.*))?$");
const boost::regex InputParser::newLine("\\\\n");

int InputParser::Parse(map<string,MacroEntry*> &vars, bool print)
{
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
        if(!inFile.good())
        {
            InputErrors::PrintWarning("unable to open file '"+file+"', ignoring.");
            return 0;
        }
        in=&inFile;
    }

    int errorCount;
    switch(type)
    {
    case XML: errorCount=ParseXML(*in,file,vars,print); break;
    default: errorCount=ParseCSV(*in,file,vars,print); break;
    }

    if(!useStdin)
    {
        inFile.close();
    }

    return errorCount;
}

int InputParser::ParseCSV(std::istream &in,
                          const std::string &currentFile,
                          std::map<std::string,MacroEntry*> &vars,
                          bool print)
{
    string line;
    boost::smatch m;
    int lineCount=0;
    int errorCount=0;

    boost::filesystem::path currentPath(currentFile);
    
    while(!in.eof())
    {
        lineCount++;
        getline(in,line);
        if(boost::regex_match(line,comment))continue;
        else if(boost::regex_match(line,m,directive))
        {
            errorCount+=EvalDirective(m[1],m[3],currentFile,lineCount,vars);
            continue;
        }
        else if(!boost::regex_match(line,m,csvLine))
        {
            InputErrors::PrintError(currentFile,lineCount,"syntax error.");
            errorCount++;
            continue;
        }
        
        string variable=m[1];
        try
        {
            Expression *expression=new Expression(m[2]);

            if(expression->IsReprint())
            {
                if(vars.find(variable)==vars.end())
                {
                    InputErrors::PrintError(currentFile,lineCount,"undefined variable '"+variable+"'.");
                    errorCount++;
                }
                else if(!vars[variable]->print)vars[variable]->print=print;
                delete expression;
                continue;
            }
            
            if(vars.find(variable)!=vars.end() &&
               (!boost::filesystem::equivalent(vars[variable]->file,currentPath) ||
                vars[variable]->line!=lineCount))
                InputErrors::PrintWarning(currentFile,lineCount,"duplicate declaration of variable '"+variable+
                                          "'.\noriginally defined in '"+vars[variable]->file.string()+"', line "+ToString(vars[variable]->line)+".");
            
            vars[variable]=new MacroEntry();
            vars[variable]->expression=expression;
            vars[variable]->print=print;
            vars[variable]->file=boost::filesystem::path(currentFile);
            vars[variable]->line=lineCount;
            if(m[4].matched)
            {
                string comment=m[4];
                vars[variable]->comments=boost::regex_replace(comment,newLine,"\\n");
            }
        }
        catch(Parser::ParserError &e)
        {
            e.Embed(true);
            InputErrors::PrintError(currentFile,lineCount,e.what());
            delete vars[variable];
            vars.erase(variable);
            errorCount++;
        }
        catch(Expression::ExpressionError &e)
        {
            e.SetVariable(variable);
            e.Embed(true);
            InputErrors::PrintError(currentFile,lineCount,e.what());
            delete vars[variable];
            vars.erase(variable);
            errorCount++;
        }
    }

    return errorCount;
}

int InputParser::ParseXML(std::istream &in,
                          const std::string &currentFile,
                          std::map<std::string,MacroEntry*> &vars,
                          bool print)
{
    return 0;
}

int InputParser::EvalDirective(const std::string &directive,
                                const std::string &parameter,
                                const std::string &currentFile,
                                int currentLine,
                                std::map<std::string,MacroEntry*> &vars,
                                bool print)
{
    if(directive=="include")
    {
        boost::smatch m;
        if(!boost::regex_match(parameter,m,boost::regex("^(!)?\"([\\/\\w.]+)\"$")))
        {
            
            cerr<<InputErrors::ErrorString(InputErrors::ERROR,
                                           currentFile,
                                           currentLine,
                                           "invalid include directive.")
                <<endl;
            return 1;
        }

        if(print)print=!m[1].matched;
        string file=m[2];
        boost::regex_match(currentFile,m,fileName);
        if(m[2].matched)file=m[2]+file;
        ifstream in(file.c_str());
        if(!in.good())
        {
            
            cerr<<InputErrors::ErrorString(InputErrors::ERROR,
                                           currentFile,
                                           currentLine,
                                           "unable to open included file \""+file+"\".")
                <<endl;
            return 1;
        }
        in.close();

        InputParser inParser(file);
        int errorCount=inParser.Parse(vars,print);
        if(errorCount>0)
        {
            cerr<<InputErrors::ErrorString(InputErrors::ERROR,
                                           currentFile,
                                           currentLine,
                                           StringHelper::ToString(errorCount)+" error"+(errorCount>0 ? "s" : "")+" from included file '"+file+"'.")
                <<endl;
        }
        return errorCount;
    }
    else
    {
            
        cerr<<InputErrors::ErrorString(InputErrors::ERROR,
                                       currentFile,
                                       currentLine,
                                       "unknown directive '"+directive+"'.")
            <<endl;
        return 1;
    }
}

void InputErrors::PrintWarning(const std::string &file,int line,const std::string &message)
{
    cerr<<InputErrors::ErrorString(WARNING,file,line,message)<<endl;
}

void InputErrors::PrintError(const std::string &file,int line,const std::string &message)
{
    cerr<<InputErrors::ErrorString(ERROR,file,line,message)<<endl;
}

std::string InputErrors::ErrorString(ErrorType type,
                                     const std::string &file,
                                     int line,
                                     const std::string &message)
{
    string header;
    string out;

    switch(type)
    {
    case ERROR: header="Error: "; break;
    case WARNING: header="Warning: "; break;
    default: header="Info: "; break;
    }
    if(file!="")header=file+(line>0 ? "("+StringHelper::ToString(line)+")" : "")+": "+header;

    string spaces="\n";
    for(int i=0;i<header.size();i++)spaces+=" ";
    out=boost::regex_replace(message,boost::regex("\\n"),spaces);
    
    return header+out;
}
