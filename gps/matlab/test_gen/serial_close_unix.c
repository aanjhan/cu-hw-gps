#include <unistd.h>
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    int device;

    /////////////////////////
    // Process Arguments
    /////////////////////////
    
    if(nrhs<1)
    {
        mexErrMsgTxt("Missing device descriptor.");
    }
    else if(nrhs>1)
    {
        mexErrMsgTxt("Too many arguments.");
    }

    //Get device descriptor.
    device=(int)mxGetScalar(prhs[0]);

    //FIXME Check if device is open.
    
    close(device);
}
