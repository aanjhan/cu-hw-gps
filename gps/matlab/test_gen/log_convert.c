#include <stdio.h>
#include <stdint.h>

int main(int argc, char *argv[])
{
    FILE *in;
    FILE *out;

    uint8_t bytes[3];
    uint8_t byteIndex;
    uint8_t bitPos;
    size_t numRead;
    uint8_t mag;
    uint8_t sign;

    uint16_t outMag;
    uint16_t outSign;
    uint8_t outPos;
    
    if(argc!=3)
    {
        printf("Invalid parameter set.\n");
        return -1;
    }

    in=fopen(argv[1],"r");
    out=fopen(argv[2],"w");

    if(in==NULL)
    {
        printf("Unable to open file '%s'.\n",argv[1]);
        fclose(in);
        fclose(out);
        return -1;
    }
    else if(out==NULL)
    {
        printf("Unable to open file '%s'.\n",argv[2]);
        fclose(in);
        fclose(out);
        return -1;
    }

    bitPos=0;
    outPos=0;
    outMag=0;
    outSign=0;
    while((numRead=fread(bytes,1,3,in))!=0)
    {
        byteIndex=0;
        while(byteIndex<numRead)
        {
            //Read packed sample from log.
            mag=(bytes[byteIndex]>>bitPos)&0x03;
            sign=(bytes[byteIndex]>>bitPos)&0x04;

            //Add bits from next byte as necessary.
            if(bitPos>=5)byteIndex++;
            if(bitPos==6)
            {
                sign=bytes[byteIndex]&0x01;
            }
            else if(bitPos==7)
            {
                mag=mag&0x01 | bytes[byteIndex]&0x01;
                sign=(bytes[byteIndex]&0x02)>>1;
            }

            //Update bit position.
            bitPos=(bitPos+3)&0x7;

            //Convert sample to output format.
            //  --Input format: [-3,+3] {sign (1b), magnitude (2b)}
            //    --Sign: 0=positive, 1=negative
            //  --Output foramt: {-3,-1,1,3} {sign (1b), magnitude (1b)}
            //    --Sign: 0=negative, 1=positive
            sign=!sign;
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
                fwrite(&outMag,2,1,out);
                fwrite(&outSign,2,1,out);
            }
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
            
    fclose(in);
    fclose(out);
    
    return 0;
}
