#include <iostream>
#include <boost/program_options.hpp>
#include <vector>
#include <ostream>
#include <fstream>
#include "expression.h"
#include "input_parser.h"

namespace opt=boost::program_options;
using namespace std;

int main(int argc, char *argv[])
{
    opt::options_description visibleOptions("Allowed options");
    visibleOptions.add_options()
        ("help,h","Display this help message.")
        ("output,o",opt::value<string>(),"Write output to specified file.");
    opt::options_description options("All program options");
    options.add(visibleOptions);
    options.add_options()("input",opt::value<vector<string> >(),"Input...");
    opt::positional_options_description pos;
    pos.add("input",-1);
    
    opt::variables_map vm;
    opt::store(opt::command_line_parser(argc,argv).options(options).positional(pos).run(),vm);
    opt::notify(vm);

    if(vm.count("help"))
    {
        cout<<"Usage: "<<argv[0]<<" [OPTION]... [FILE]..."<<endl
            <<"Generate Verilog include file from XML variable"<<endl
            <<"definitions file."<<endl
            <<endl<<visibleOptions<<endl
            <<"If supplied, input is read from the listed files."<<endl
            <<"By default, input is taken from stdin and output"<<endl
            <<"is written to stdout."<<endl;
        return 0;
    }

    //Parse input files.
    map<string,Expression*> vars;
    map<string,string> comments;
    if(vm.count("input"))
    {
        vector<string> inputFiles=vm["input"].as<vector<string> >();
        for(vector<string>::iterator i=inputFiles.begin();
            i!=inputFiles.end();
            i++)
        {
            InputParser in(*i);
            try{ in.Parse(vars,comments); }
            catch(exception &e){ cout<<e.what()<<endl; }
        }
    }
    else
    {
        InputParser in;
        try{ in.Parse(vars,comments); }
        catch(exception &e){ cout<<e.what()<<endl; }
    }

    //Print output file.
    ofstream outFile;
    ostream *out=NULL;
    if(!vm.count("output"))out=&cout;
    else
    {
        outFile.open(vm["output"].as<string>().c_str());
        if(outFile.good())out=&outFile;
        else cout<<"Error: unable to open output file '"
                 <<vm["output"].as<string>()<<"'."<<endl;
    }
    if(out!=NULL)
    {
        int errorCount=0;

        string output;
        output="//This file has been automatically generated.\n";
        output+="//Edit contents with extreme caution.\n\n";

        boost::regex newline("\\n");
        for(map<string,Expression*>::iterator i=vars.begin();
            i!=vars.end();
            i++)
        {
            try
            {
                if(comments.find((*i).first)!=comments.end())
                {
                    output+="//";
                    output+=boost::regex_replace(comments[(*i).first],newline,"\\n//");
                    output+="\n";
                }
                output+="`define "+(*i).first
                        +" "+(*i).second->Value(vars)+"\n\n";
            }
            catch(exception &e)
            {
                errorCount++;
                cout<<e.what()<<endl;
            }
        }

        if(errorCount==1)cout<<"1 error."<<endl;
        else if(errorCount>0)cout<<errorCount<<" errors."<<endl;
        else (*out)<<output;

        if(vm.count("output"))outFile.close();
    }

    //Cleanup expressions.
    for(map<string,Expression*>::iterator i=vars.begin();
        i!=vars.end();
        i++)
    {
        delete (*i).second;
    }
    
    return 0;
}
