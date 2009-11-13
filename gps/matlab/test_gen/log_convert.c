#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define FORMAT_HW 0
#define FORMAT_SW 1

//Buffer size in samples. Must be a common multiple
//of 5 and 16 to maintain aligned numbers of
//HW and SW words.
//HW - 5 samples / 3 bytes
//SW - 16 samples / 4 bytes
#define BUFFER_SIZE 80
#define HW_BUFFER_SIZE ((BUFFER_SIZE/5)*3)
#define SW_BUFFER_SIZE ((BUFFER_SIZE/16)*4)

int ReadHWFormat(FILE *file, int8_t *samples)
{
    int numBytes;
    int numSamples;
    
    uint8_t buffer[HW_BUFFER_SIZE];
    uint16_t magWord, signWord;

    uint8_t byteIndex;
    uint8_t bitPos;
    
    int i;
    uint8_t mag;
    uint8_t negative;

    numBytes=fread(buffer,1,HW_BUFFER_SIZE,file);

    //FIXME This code doesn't work yet!
    /*bitPos=0;
    outPos=0;
    outMag=0;
    outSign=0;
    while(numBytes>0)
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
                mag=mag&0x01 | (bytes[byteIndex]&0x01)<<1;
                sign=(bytes[byteIndex]&0x02)>>1;
            }
            if(sign)sign=1;

            //Update bit position.
            bitPos=(bitPos+3)&0x7;

            //Convert sample to output format.
            //  --Input format: [-3,+3] {sign (1b), magnitude (2b)}
            //    --Sign: 0=positive, 1=negative
            //  --Output foramt: {-3,-1,1,3} {sign (1b), magnitude (1b)}
            //    --Sign: 0=negative, 1=positive
            sign=!sign;
            mag>>=1;
        }
        }*/

    return 0;
}

int ReadSWFormat(FILE *file, int8_t *samples)
{
    int numBytes;
    int numSamples;
    
    uint8_t buffer[SW_BUFFER_SIZE];
    uint16_t magWord, signWord;
    
    int i;
    uint8_t mag;
    uint8_t negative;

    numBytes=fread(buffer,1,SW_BUFFER_SIZE,file);

    numSamples=0;
    while(numBytes/4>0)
    {
        magWord=(buffer[0]<<8)|buffer[1];
        signWord=(buffer[1]<<8)|buffer[2];
        numBytes-=4;

        for(i=0;i<16;i++)
        {
            //Read software-format sign and magnitude.
            //Magnitude: 0=1, 1=3
            //Sign: 0=negative, 1=positive
            mag=(magWord&0x8000) ? 3 : 1;
            negative=(!(signWord&0x8000)) ? 1 : 0;

            samples[numSamples++]=negative ? -((int8_t)mag) : ((int8_t)mag);

            magWord<<=1;
            signWord<<=1;
        }
    }

    return numSamples;
}

void WriteHWFormat(FILE *file, int8_t *samples, int numSamples)
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

void WriteSWFormat(FILE *file, int8_t *samples, int numSamples)
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

int main(int argc, char *argv[])
{
    char *formatString;
    int format;
    
    FILE *in;
    FILE *out;

    int numSamples;
    int8_t samples[BUFFER_SIZE];
    
    if(argc<3)
    {
        printf("Invalid parameter set.\n");
        return -1;
    }

    if(argc==4)
    {
        format=-1;
        formatString=argv[3];
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

        if(format<0)
        {
            printf("Unsupported log format.\n");
            return -1;
        }
    }
    else format=FORMAT_HW;

    in=fopen(argv[1],"r");
    out=fopen(argv[2],"w");

    if(in==NULL)
    {
        printf("Unable to open file '%s'.\n",argv[1]);
        return -1;
    }
    else if(out==NULL)
    {
        printf("Unable to open file '%s'.\n",argv[2]);
        fclose(in);
        return -1;
    }

    do
    {
        if(format==FORMAT_HW)numSamples=ReadHWFormat(in,samples);
        else numSamples=ReadSWFormat(in,samples);
        
        if(format==FORMAT_HW)WriteSWFormat(in,samples,numSamples);
        else WriteHWFormat(in,samples,numSamples);
    }
    while(numSamples==BUFFER_SIZE);
            
    fclose(in);
    fclose(out);
    
    return 0;
}
