#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    char *deviceName;
    int device;
    struct termios options;

    /////////////////////////
    // Process Arguments
    /////////////////////////
    
    if(nrhs<1)
    {
        msgErrMsgTxt("Missing device name.");
    }
    else if(nrhs>1)
    {
        msgErrMsgTxt("Too many arguments.");
    }

    //Get device name.
    deviceName=mxArrayToString(prhs[0]);

    ///////////////
    // Setup Port
    ///////////////

    //Open serial port.
    device=open(deviceName,O_RDWR|O_NOCTTY|O_NDELAY);
    mxFree(deviceName);
    if(device==-1)
    {
        msgErrMsgTxt("Unable to open device.\n");
    }
    
    //Specify baud rate.
    tcgetattr(device,&options);
    if(cfsetispeed(&options,B115200)!=0 ||
       cfsetospeed(&options,B115200)!=0)
    {
        close(device);
        msgErrMsgTxt("Unable to set baud rate to 115200.\n");
    }

    //Local mode flags.
    options.c_lflag&=~ICANON;//Disable canonical mode.
    options.c_lflag&=~(ECHO|ECHONL);//Disable echo.
    options.c_lflag&=~IEXTEN;//Disable extended processing.
    options.c_lflag&=~ISIG;//Disable signal characters.

    //Character processing flags.
    options.c_cflag|=CLOCAL;//Ignore modem status lines.
    options.c_cflag&=~PARENB;//No parity.
    options.c_cflag&=~CSIZE;//Clear character mask
    options.c_cflag|=CS8;//Force 8-bit input mode.
    options.c_cflag|=CREAD;//Enable receiver.

    //Input flags.
    options.c_iflag&=~(ICRNL|INLCR);//Disable new-line translation.
    options.c_iflag&=~(PARMRK|INPCK);//Disable parity checking/marking.
    options.c_iflag&=~ISTRIP;//Disable high-bit stripping.
    options.c_iflag&=~(IXON|IXOFF);//Disable flow control.

    //Set options.
    if(tcsetattr(device,TCSANOW,&options)!=0)
    {
        close(device);
        msgErrMsgTxt("Unable to change device settings.\n");
    }

    //Return device descriptor.
    plhs[0]=mxCreateDoubleScalar(device);
}
