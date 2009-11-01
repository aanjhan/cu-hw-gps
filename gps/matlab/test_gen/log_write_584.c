#include <stdio.h>
#include <stdint.h>
#include <math.h>
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
    
    uint16_t outMag;
    uint16_t outSign;
    uint8_t outPos;
    
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

    outPos=0;
    outMag=0;
    outSign=0;
    for(i=0;i<numSamples;i++)
    {
        //Convert sample format to software receiver log format.
        samples[i]=(samples[i]+3)/2;
        samples[i]=floor(samples[i]+0.5)-1.5;
        
        //Get sign/magnitude of sample.
        //Note: Software receiver sign format is inverted
        //      as compared to hardware receiver.
        sign=samples[i]<0 ? 1 : 0;
        mag=sign ? (uint8_t)(-samples[i]) : (uint8_t)samples[i];
        sign=!sign;

        //Append sample to output word.
        outMag<<=1;
        outMag|=mag;
        outSign<<=1;
        outSign|=sign;

        //Write words, magnitude first, if full.
        if(++outPos==16)
        {
            outPos=0;
            fwrite(&outMag,2,1,out);
            fwrite(&outSign,2,1,out);
        }
    }

    //Write last word if partially-complete.
    if(outPos!=0)
    {
        outMag<<=(15-outPos);
        outSign<<=(15-outPos);
        fwrite(&outMag,2,1,out);
        fwrite(&outSign,2,1,out);
    }

    fclose(out);
    mxFree(fileName);
}
