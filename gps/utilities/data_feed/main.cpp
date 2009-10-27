#include <iostream>
#include <string>
#include <vector>
#include <boost/program_options.hpp>
#include <signal.h>
#include "string_helper.hpp"
#include "raw_socket.hpp"
#include "data_feed.hpp"

using namespace std;
using namespace StringHelper;
namespace po = boost::program_options;

const char *PROJECT_NAME = "DataFeed";
const char *PACKAGE_NAME = "data_feed";
const char *VERSION = "0.1";
const char *AUTHOR = "Adam Shapiro";
const char *AUTHOR_EMAIL = "ams348@cornell.edu";

//FIXME Read these from a config file?
const long BIT_RATE = 50400000;//Bit rate (bps).
const int BURST_SIZE = 60;//Individual burst size (B) - should be a multiple of 6B.

DataFeed *feed=NULL;

void Interrupt(int signal)
{
    feed->Stop();
}

void PrintHelp(const po::options_description &options)
{
    cout<<PROJECT_NAME<<" version "<<VERSION<<"."<<endl
        <<endl
        <<"Usage: "<<PACKAGE_NAME<<" [OPTION]... DEV FILE"<<endl
        <<endl
        <<"Feed a data log file over the specified Ethernet device"<<endl
        <<"at a constant bit-rate, in fixed-size packets."<<endl
        <<endl
        <<options
        <<endl
        <<"Note: "<<PROJECT_NAME<<" must be run as root on Unix-based systems."<<endl
        <<endl
        <<"Written by "<<AUTHOR<<" <"<<AUTHOR_EMAIL<<">."<<endl;
}

int main(int argc, char *argv[])
{
    long bitRate=BIT_RATE;
    int burstSize=BURST_SIZE;
    string deviceName;
    string file="";

    po::options_description allowedOpt("Allowed options");
    allowedOpt.add_options()
        ("devices,d","List available devices.")
        ("help,h","Display help message.")
        ("rate,r",po::value<int>(),"Data bit-rate (bps).")
        ("size,s",po::value<int>(),"Burst size (bytes).")
        ("version,v","Show version information.");

    po::options_description hiddenOpt("Hidden options");
    hiddenOpt.add_options()
        ("device",po::value<string>())
        ("file",po::value<string>());
    
    po::positional_options_description posOpt;
    posOpt.add("device",1).add("file",-1);

    po::options_description options;
    options.add(allowedOpt).add(hiddenOpt);

    po::variables_map vm;
    po::store(po::command_line_parser(argc,argv).options(options).positional(posOpt).run(), vm);
    po::notify(vm); 

    if(vm.count("help"))
    {
        PrintHelp(allowedOpt);
        return 0;
    }
    else if(vm.count("devices"))
    {
        vector<string> deviceList;

        try
        {
            RawSocket::ListDevices(deviceList);
                
            int numDevices=0;
            for(vector<string>::iterator itr=deviceList.begin();
                itr!=deviceList.end();
                itr++)
            {
                cout<<++numDevices<<". "<<(*itr)<<endl;
            }

            if(numDevices==0)
            {
                cout<<"No devices found."<<endl;
            }
                
            return 0;
        }
        catch(IOException &e)
        {
            cout<<e.what()<<endl;
            return -1;
        }
    }

    if(vm.count("rate"))
    {
        bitRate=(long)vm["rate"].as<int>();
    }

    if(vm.count("size"))
    {
        burstSize=vm["size"].as<int>();
    }
    
    if(vm.count("device"))
    {
        deviceName=vm["device"].as<string>();
        if(IsInt(deviceName))
        {
            vector<string> deviceList;
            unsigned int i;
            FromString(deviceName,i);

            try
            {
                RawSocket::ListDevices(deviceList);
                if(i>deviceList.size() || i<1)throw IOException("unknown device");
                deviceName=deviceList[i-1];
            }
            catch(IOException &e)
            {
                cout<<e.what()<<endl;
                return -1;
            }
        }
    }
    else
    {
        cout<<"Error: missing device name."<<endl;
        return -1;
    }
    
    if(vm.count("file"))
    {
        file=vm["file"].as<string>();
    }
    else
    {
        cout<<"Error: missing log file."<<endl;
        return -1;
    }

    RawSocket sock;
    try
    {
        //Create data feed.
        feed=new DataFeed(file,sock,bitRate,burstSize);
        
        //Register to catch Ctrl-C.
        signal(SIGINT,Interrupt);
        
        //Open device.
        sock.Open(deviceName);

        //Run feed until Ctrl-C is caught.
        feed->Start();
        while(feed->IsRunning());
        delete feed;

        //Close device.
        sock.Close();
    }
    catch(IOException e)
    {
        cout<<e.what()<<endl;
        return -1;
    }

    return 0;
}
