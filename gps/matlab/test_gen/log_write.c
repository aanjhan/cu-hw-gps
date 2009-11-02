#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "mex.h"

#define FORMAT_HW 0
#define FORMAT_SW 1

void WriteHWFormat(FILE *file, double *samples, mwSize numSamples)
{
    int i;
    uint8_t mag;
    uint8_t sign;
    
    uint8_t byteIndex;
    uint8_t bytes[3];
    uint8_t bitPos;
    
    bitPos=0;
    byteIndex=0;
    bytes[0]=bytes[1]=bytes[2]=0;
    for(i=0;i<numSamples;i++)
    {
        //Get sign/magnitude of sample.
        sign=samples[i]<0;
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
            fwrite(bytes,3,1,file);
            byteIndex=0;
            bytes[0]=bytes[1]=bytes[2]=0;
        }
    }

    //Write remaining data.
    if(bitPos!=0)
    {
        byteIndex=0;
        fwrite(bytes,byteIndex+1,1,file);
    }
}

void WriteSWFormat(FILE *file, double *samples, mwSize numSamples)
{
    int i;
    uint8_t mag;
    uint8_t sign;
    
    uint16_t outMag;
    uint16_t outSign;
    uint8_t outPos;
    uint8_t outByte[2];

    outPos=0;
    outMag=0;
    outSign=0;
    for(i=0;i<numSamples;i++)
    {
        //Get sign/magnitude of sample.
        //Note: Software receiver sign format is inverted
        //      as compared to hardware receiver.
        sign=samples[i]>=0;
        mag=!sign ? (uint8_t)(-samples[i]) : (uint8_t)samples[i];
        mag>>=1;

        //Append sample to output word.
        outMag<<=1;
        outMag|=mag;
        outSign<<=1;
        outSign|=sign;

        //Write words, magnitude first, if full.
        if(++outPos==16)
        {
            outPos=0;
            outByte[0]=(outMag>>8)&0xFF;
            outByte[1]=outMag&0xFF;
            fwrite(outByte,1,2,file);
            outByte[0]=(outSign>>8)&0xFF;
            outByte[1]=outSign&0xFF;
            fwrite(outByte,1,2,file);
        }
    }

    //Write last word if partially-complete.
    if(outPos!=0)
    {
        outMag<<=(15-outPos);
        outSign<<=(15-outPos);
        outByte[0]=(outMag>>8)&0xFF;
        outByte[1]=outMag&0xFF;
        fwrite(outByte,1,2,file);
        outByte[0]=(outSign>>8)&0xFF;
        outByte[1]=outSign&0xFF;
        fwrite(outByte,1,2,file);
    }
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    FILE *out;
    char *fileName;
    char *formatString;
    int format;

    mwSize numSamples;
    double *samples;
    
    if(nrhs<2)
    {
        mexErrMsgTxt("Not enough arguments.");
    }
    else if(nrhs>3)
    {
        mexErrMsgTxt("Too many arguments.");
    }

    if(nrhs==3)
    {
        format=-1;
        formatString=mxArrayToString(prhs[2]);
        if(strcmp(formatString,"hw")==0 ||
           strcmp(formatString,"HW")==0)
        {
            format=FORMAT_HW;
        }
        else if(strcmp(formatString,"sw")==0 ||
                strcmp(formatString,"SW")==0)
        {
            format=FORMAT_SW;
        }

        mxFree(formatString);

        if(format<0)mexErrMsgTxt("Unsupported log format.");
    }
    else format=FORMAT_HW;

    fileName=mxArrayToString(prhs[1]);
    out=fopen(fileName,"w");
    mxFree(fileName);

    if(out==NULL)mexErrMsgTxt("Unable to open file.");

    numSamples=mxGetM(prhs[0]);
    samples=mxGetPr(prhs[0]);

    if(format==FORMAT_SW)
    {
        WriteSWFormat(out,samples,numSamples);
    }
    else
    {
        WriteHWFormat(out,samples,numSamples);
    }

    fclose(out);
}
