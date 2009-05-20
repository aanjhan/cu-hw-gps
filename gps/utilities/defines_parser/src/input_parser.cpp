#include <iostream>
#include <fstream>
#include <algorithm>
#include "input_parser.h"

using namespace std;

const boost::regex InputParser::fileName("^(.*)\\.(.*)$");
const boost::regex InputParser::csvLine("^([A-Za-z_]\\w*),([^,]*)(,(.*))?$");
const boost::regex InputParser::newLine("\\\\n");

void InputParser::Parse(map<string,Expression*> &vars, std::map<std::string,std::string> &comments) throw(SyntaxError,FileNotFoundException)
{
    map<string,Expression*> tempVars;

    if(file=="-")useStdin=true;

    FileType type=CSV;
    ifstream inFile;
    istream *in;
    if(useStdin)
    {
        in=&cin;
    }
    else
    {
        boost::smatch m;
        if(boost::regex_match(file,m,fileName))
        {
            if(m[2]=="xml")type=XML;
        }
        
        inFile.open(file.c_str());
        if(!inFile.good())throw FileNotFoundException(file);
        in=&inFile;
    }

    try
    {
        switch(type)
        {
        case XML: ParseXML(*in,tempVars,comments); break;
        default: ParseCSV(*in,tempVars,comments); break;
        }
    }
    catch(LineSyntaxError &e)
    {
        for(map<string,Expression*>::iterator i=tempVars.begin();
            i!=tempVars.end();
            i++)
        {
            delete (*i).second;
        }
        
        if(!useStdin)
        {
            inFile.close();
            throw SyntaxError(file,e.what());
        }
        else throw SyntaxError(e.what());
    }

    if(!useStdin)
    {
        inFile.close();
    }

    copy(tempVars.begin(),tempVars.end(),inserter(vars,vars.end()));
}

void InputParser::ParseCSV(std::istream &in,
                           std::map<std::string,Expression*> &vars,
                           std::map<std::string,std::string> &comments) throw(LineSyntaxError)
{
    string line;
    boost::smatch m;
    int lineCount=0;
    while(!in.eof())
    {
        lineCount++;
        getline(in,line);
        if(line=="")continue;
        else if(!boost::regex_match(line,m,csvLine))throw LineSyntaxError(lineCount);
        
        if(vars.find(m[1])!=vars.end())cout<<"Warning: duplicate declaration of variable '"<<m[1]<<"'."<<endl;
        try
        {
            vars[m[1]]=new Expression(m[2]);
            if(m[4].matched)
            {
                string comment=m[4];
                comments[m[1]]=boost::regex_replace(comment,newLine,"\\n");
            }
        }
        catch(...){ throw LineSyntaxError(lineCount); }
    }
}
void InputParser::ParseXML(std::istream &in,
                           std::map<std::string,Expression*> &vars,
                           std::map<std::string,std::string> &comments) throw(LineSyntaxError)
{
}
