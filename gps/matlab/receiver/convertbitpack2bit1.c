#include "mex.h"
#include "matrix.h"

/*
 * convertbitpack2bit1.c
 *
 * written by Brent Ledvina
 *
 * 4/16/2004
 */
 

void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[] )
{
  unsigned int *x; 
  /*double *x;*/
  double *y;
  int s,m;
  int N,i,j,idx,comb;
  int     mrows,ncols;
  
  /* Check for proper number of arguments. */
  if(nrhs!=1) {
    mexErrMsgTxt("One input required.");
  } else if(nlhs>1) {
    mexErrMsgTxt("Too many output arguments");
  }
  
  /* The input must be a noncomplex scalar double.*/
  mrows = mxGetM(prhs[0]);
  ncols = mxGetN(prhs[0]);
  if( !mxIsClass(prhs[0],"uint32") || mxIsComplex(prhs[0]) ||
      !(ncols==1) ) {
    mexErrMsgTxt("Input must be a noncomplex vector uint32.");
  }
  
  /* I am _assuming_ that the return argument has 
   * already been allocated. If it has not, uncomment
   * the second line of code below
   */
 
  /* Create matrix for the return argument. */
  plhs[0] = mxCreateDoubleMatrix(16*mrows,ncols,mxREAL);
  
  /* Assign pointers to each input and output. */
  x = (unsigned int*)mxGetData(prhs[0]);
  y = mxGetPr(plhs[0]);
  

  /* Unpack the bit-packed data.  
   * sign bits are the lower 16, while the mag
   * bits are the upper 16. */
  idx=0;
  N=mrows;
  for(i=0;i<N;i++) {
     s = (x[i])&0xffff;
     m = ((x[i])>>16)&0xffff;
    
     for(j=15;j>=0;j--) {
       comb = (2*((s>>j)&0x1) - 1)*(1 + 2*((m>>j)&0x1));
       y[idx]=(double)comb;
       idx++;
     }
  }

}
