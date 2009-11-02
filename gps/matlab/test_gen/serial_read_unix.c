#include <sys/types.h>
#include <stdint.h>
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    int device;
    ssize_t readLength;
    uint8_t elementSize;
    mxClassID elementClass;
    
    struct termios options;
    void *data;
    int ret;
    int bytesRead;
    ssize_t numBytes;
    clock_t startTime;

    /////////////////////////
    // Process Arguments
    /////////////////////////
    
    if(nrhs<1)
    {
        mexErrMsgTxt("Missing device descriptor.");
    }
    else if(nrhs>3)
    {
        mexErrMsgTxt("Too many arguments.");
    }

    //Get device descriptor.
    device=(int)mxGetScalar(prhs[0]);

    //FIXME Check that device is open (and a tty).

    //Set read length.
    if(nrhs>=2)
    {
        readLength=(ssize_t)mxGetScalar(prhs[1]);
    }
    else
    {
        readLength=1;
    }

    //Get element class.
    //Default is uint8_t.
    if(nrhs>=3)
    {
        char *type;
        type=mxArrayToString(prhs[2]);
        if(strcmp(type,"int8")==0)
        {
            elementSize=sizeof(int8_t);
            elementClass=mxINT8_CLASS;
        }
        else if(strcmp(type,"uint16")==0)
        {
            elementSize=sizeof(uint16_t);
            elementClass=mxUINT16_CLASS;
        }
        else if(strcmp(type,"int16")==0)
        {
            elementSize=sizeof(int16_t);
            elementClass=mxINT16_CLASS;
        }
        else if(strcmp(type,"uint32")==0)
        {
            elementSize=sizeof(uint32_t);
            elementClass=mxUINT32_CLASS;
        }
        else if(strcmp(type,"int32")==0)
        {
            elementSize=sizeof(int32_t);
            elementClass=mxINT32_CLASS;
        }
        else if(strcmp(type,"float")==0)
        {
            elementSize=sizeof(float);
            elementClass=mxSINGLE_CLASS;
        }
        else if(strcmp(type,"double")==0)
        {
            elementSize=sizeof(double);
            elementClass=mxDOUBLE_CLASS;
        }
        else
        {
            elementSize=sizeof(uint8_t);
            elementClass=mxUINT8_CLASS;
        }
        mxFree(type);
    }
    else
    {
        elementSize=sizeof(uint8_t);
        elementClass=mxUINT8_CLASS;
    }

    ///////////////
    // Read Data
    ///////////////

    //Setup data array.
    numBytes=readLength*elementSize;
    data=malloc(numBytes);

    //Read data.
    startTime=clock();
    bytesRead=0;
    do
    {
        ret=read(device,data,numBytes-bytesRead);
        if(ret>0)bytesRead+=ret;
    }
    while(bytesRead<numBytes && (clock()-startTime)<0.2*CLOCKS_PER_SEC);

    //Return read values.
    readLength=bytesRead/elementSize;
    plhs[0]=mxCreateNumericMatrix(readLength,1,elementClass,mxREAL);
    memcpy((void*)mxGetPr(plhs[0]),data,readLength*elementSize);

    //Free data array.
    free(data);
}
