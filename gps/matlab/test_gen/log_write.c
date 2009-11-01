#include <stdio.h>
#include <stdint.h>
#include "mex.h"


void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    FILE *out;
    char *fileName;

    int i;
    mwSize numSamples;
    double *samples;

    uint8_t mag;
    uint8_t sign;
    uint8_t byteIndex;
    uint8_t bytes[3];
    uint8_t bitPos;
    
    if(nrhs<2)
    {
        msgErrMsgTxt("Not enough arguments.");
    }
    else if(nrhs>2)
    {
        msgErrMsgTxt("Too many arguments.");
    }

    fileName=mxArrayToString(prhs[1]);
    out=fopen(fileName,"w");

    if(out==NULL)
    {
        mxFree(fileName);
        mexErrMsgTxt("Unable to open file.");
    }

    numSamples=mxGetM(prhs[0]);
    samples=mxGetPr(prhs[0]);

    bitPos=0;
    byteIndex=0;
    bytes[0]=bytes[1]=bytes[2]=0;
    for(i=0;i<numSamples;i++)
    {
        //Get sign/magnitude of sample.
        sign=samples[i]<0 ? 1 : 0;
        mag=sign ? (uint8_t)(-samples[i]) : (uint8_t)samples[i];

        //Pack 3-bit samples into 8-bit words.
        if(bitPos==6)
        {
            bytes[byteIndex]|=(mag<<bitPos)&0xFF;
            bytes[++byteIndex]|=sign;
        }
        else if(bitPos==7)
        {
            bytes[byteIndex]|=(mag<<bitPos)&0xFF;
            bytes[++byteIndex]|=mag>>1;
            bytes[byteIndex]|=sign<<1;
        }
        else
        {
            bytes[byteIndex]|=((sign<<2)|mag)<<bitPos;
        }

        //Update bit position.
        bitPos=(bitPos+3)&0x7;

        //Write data if 3 bytes filled.
        if(bitPos==0)
        {
            fwrite(bytes,3,1,out);
            byteIndex=0;
            bytes[0]=bytes[1]=bytes[2]=0;
        }
    }

    //Write remaining data.
    if(bitPos!=0)
    {
        byteIndex=0;
        fwrite(bytes,byteIndex+1,1,out);
    }

    fclose(out);
    mxFree(fileName);
}
