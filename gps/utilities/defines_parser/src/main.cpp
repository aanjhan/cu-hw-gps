#include <iostream>
#include <boost/program_options.hpp>
#include <vector>
#include "expression.h"

namespace opt=boost::program_options;
using namespace std;

int main(int argc, char *argv[])
{
    opt::options_description visibleOptions("Allowed options");
    visibleOptions.add_options()
        ("help,h","Display this help message.")
        ("output,o",opt::value<string>()->default_value(""),"Write output to specified file.");
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

    if(vm.count("input"))
    {
        vector<string> inputFiles=vm["input"].as<vector<string> >();
        for(vector<string>::iterator i=inputFiles.begin();
            i!=inputFiles.end();
            i++)
        {
            cout<<"Input file: "<<*i<<endl;
        }
    }
    
    map<string,Expression*> vars;
    vars["A"]=new Expression("8");
    vars["B"]=new Expression("-2*A");
    Expression e("log2(A)+A");
    string v=e.Value(vars);
    cout<<"Value: "<<v<<endl;

    for(map<string,Expression*>::iterator i=vars.begin();
        i!=vars.end();
        i++)
    {
        delete (*i).second;
    }
    
    return 0;
}
