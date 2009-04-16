#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>

int main(int argc, char *argv[])
{
    int port;
    FILE *file;
    int value;
    unsigned char c;
    struct termios options;
    
    if(argc<3)
    {
        printf("Usage: argv[0] device filename.\n");
        return 0;
    }

    port=open(argv[1],O_WRONLY|O_NOCTTY|O_NDELAY);
    if(port==-1)
    {
        printf("Unable to open device %s.\n",argv[1]);
        return 1;
    }
    tcgetattr(port,&options);
    if(cfsetispeed(&options,B115200)!=0 ||
       cfsetospeed(&options,B115200)!=0)
    {
        printf("Unable to set baud rate.\n");
        close(port);
        return 1;
    }
    options.c_cflag|=CLOCAL;
    options.c_cflag&=~(IXON|IXOFF|IXANY);
    options.c_cflag&=~CRTSCTS;
    options.c_cflag&=~(ICANON|ECHO|ECHOE|ISIG);
    if(tcsetattr(port,TCSANOW,&options)!=0)
    {
        printf("Unable to update device settings.\n");
        close(port);
        return 1;
    }

    file=fopen(argv[2],"r");
    if(file==NULL)
    {
        printf("Unable to open file %s.\n",argv[2]);
        close(port);
        return 2;
    }

    while(!feof(file))
    {
        value=fgetc(file);
        if(value==EOF)break;
        c=value;
        if(write(port,&c,1)<0)
        {
            printf("ERROR: Failed to write byte 0x%02X. Received error %d.\n",c, errno);
        }
    }

    fclose(file);
    close(port);
    
    return 0;
}
