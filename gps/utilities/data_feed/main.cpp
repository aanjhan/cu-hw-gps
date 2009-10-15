#include <iostream>
#include <string.h>
#include <vector>
#include "raw_socket.hpp"

void PrintHelp();

using namespace std;

const char *PROJECT_NAME = "DataFeed";
const char *PACKAGE_NAME = "data_feed";
const char *VERSION = "0.1";
const char *AUTHOR = "Adam Shapiro";
const char *AUTHOR_EMAIL = "ams348@cornell.edu";

//FIXME Read these from a config file?
const int BIT_RATE = 50400000;//Bit rate (bps).
const int BURST_SIZE = 60;//Individual burst size (B) - should be a multiple of 6B.

int main(int argc, char *argv[])
{
    char *device_name=NULL;
    
    for(int i=1;i<argc;i++)
    {
        if(strcmp(argv[i],"-h")==0 || strcmp(argv[i],"--help")==0)
        {
            PrintHelp();
            return 0;
        }
        //List devices.
        else if(strcmp(argv[i],"-d")==0)
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
        //Device specified.
        else if(argv[i][0]!='-' && device_name==NULL)
        {
            device_name=argv[i];
        }
    }

    if(device_name==NULL)
    {
        PrintHelp();
        return -1;
    }

    RawSocket sock;
    try
    {
        //Open device.
        sock.Open(device_name);
        
        char data[10]={0,1,2,3,4,5,6,7,8,9};
        sock.Write(data,10);

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

void PrintHelp()
{
    cout<<PROJECT_NAME<<" version "<<VERSION<<"."<<endl
        <<endl
        <<"Usage: "<<PACKAGE_NAME<<" [OPTION]... DEV FILE"<<endl
        <<endl
        <<"Feed a data log file over the specified Ethernet device"<<endl
        <<"at a constant bit-rate, in fixed-size packets."<<endl
        <<endl
        <<"  -h [--help]    Display this help message."<<endl
        <<"  -v [--version] Show version information."<<endl
        <<endl
        <<"Note: "<<PROJECT_NAME<<" must be run as root on Unix-based systems."<<endl
        <<endl
        <<"Written by "<<AUTHOR<<" <"<<AUTHOR_EMAIL<<">."<<endl;
}
