#include <alt_types.h>
#include <sys/alt_stdio.h>
#include <sys/alt_alarm.h>
#include <altera_avalon_pio_regs.h>
#include <altera_avalon_uart_regs.h>
#include <sys/alt_irq.h>
#include "system.h"

#ifndef NULL
#define NULL 0
#endif

#define LED_TICKS (alt_ticks_per_second()/2)
#define DATA_TICKS (alt_ticks_per_second()/50)

#define GPS_DATA_CLOCK 0x08
#define GPS_RESET      0x80
#define GPS_DATA       0x07

#define CONTROL_STATE_B0      0
#define CONTROL_STATE_B1      1
#define CONTROL_STATE_CMD     2
#define CONTROL_STATE_LEN0    3
#define CONTROL_STATE_LEN1    4
#define CONTROL_STATE_PAYLOAD 5

#define CONTROL_B0 0xFE
#define CONTROL_B1 0xED

#define CONTROL_CMD_DOWNLOAD      1
#define CONTROL_CMD_DOWNLOAD_WORD 2
#define CONTROL_CMD_UPLOAD        3
#define CONTROL_CMD_RESET_FEED    4
#define CONTROL_CMD_START_FEED    5
#define CONTROL_CMD_STOP_FEED     6

typedef struct
{
    alt_u8 *data;
    alt_u32 numWords;
    
    alt_u16 readIndex;
    alt_u8 readOffset;
    alt_u32 readWord;
    
    alt_u16 writeIndex;
    alt_u8 writeOffset;
    alt_u32 writeWord;
} GPSDataBuffer;

volatile alt_u8 leds;
static alt_alarm ledAlarm;

volatile int running;
volatile alt_u8 gpsDataOut;
volatile GPSDataBuffer gpsData;
static alt_alarm dataAlarm;

alt_u8 controlState;
alt_u16 controlLength;
alt_u8 controlCommand;
alt_u16 controlBytesRead;

void ControlEval(alt_u8 byte);
void ControlEvalCommand();
void ControlEvalPayload(alt_u8 byte);

void InitializeBuffer(GPSDataBuffer *buffer, alt_u8 *address);
alt_u8 ReadGPSWord(GPSDataBuffer *buffer, alt_u8 *value);
void WriteGPSWord(GPSDataBuffer *buffer, alt_u8 value);
void WriteGPSByte(GPSDataBuffer *buffer, alt_u8 value);

alt_u32 LEDTick(void* context)
{
    //Update status LEDs.
    leds<<=1;
    if(leds==0x80)leds=0x81;
    else if(leds==0x02)leds=0x03;
    IOWR_ALTERA_AVALON_PIO_DATA(LEDS_BASE,leds);
    return LED_TICKS;
}

alt_u32 DataTick(void* context)
{
    alt_u8 value, ret=1;
    
    //Send next data word.
    gpsDataOut^=GPS_DATA_CLOCK;
    if(gpsDataOut&GPS_DATA_CLOCK)
    {
        gpsDataOut&=~(GPS_RESET | GPS_DATA);
        
        ret=ReadGPSWord((GPSDataBuffer*)&gpsData,&value);
        gpsDataOut|=value;
        
        //Setup data before clock.
        IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,value);
    }
    IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,gpsDataOut);
    
    if(!ret)running=0;
    
    return ret ? DATA_TICKS : 0;
}

void StartFeed(void *context, alt_u32 id)
{
    if(!running)
    {
        running=1;
        gpsDataOut=GPS_RESET;
        IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,gpsDataOut);
        gpsDataOut|=GPS_DATA_CLOCK;
        IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,gpsDataOut);
        alt_alarm_start(&dataAlarm,DATA_TICKS,DataTick,0);
    }
    else
    {
        alt_alarm_stop(&dataAlarm);
        gpsData.readIndex=0;
        gpsData.readOffset=0;
        gpsData.readWord=0;
        running=0;
    }
    
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(START_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(START_BASE,0x01);
}

void DataUART_IRQ(void *context, alt_u32 id)
{
    alt_u32 status;
    
    status=IORD_ALTERA_AVALON_UART_STATUS(DATA_UART_BASE);
    
    if(status&ALTERA_AVALON_UART_STATUS_RRDY_MSK)
    {
        ControlEval(IORD_ALTERA_AVALON_UART_RXDATA(DATA_UART_BASE));
    }
    
    IOWR_ALTERA_AVALON_UART_STATUS(DATA_UART_BASE,0);
}

int main()
{
    alt_u8 i;
     
    alt_putstr("Data feeder initializing...\n");
  
    IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,0xFF);
  
    leds=0xC0;

    controlState=CONTROL_STATE_B0;
    IOWR_ALTERA_AVALON_UART_CONTROL(DATA_UART_BASE,ALTERA_AVALON_UART_CONTROL_RRDY_MSK);
    alt_irq_register(DATA_UART_IRQ,NULL,DataUART_IRQ);
    
    running=0;
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(START_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(START_BASE,0x01);
    alt_irq_register(START_IRQ,NULL,StartFeed);

    InitializeBuffer((GPSDataBuffer*)&gpsData,(alt_u8*)SDRAM_BASE);
    for(i=0;i<8;i++)WriteGPSWord((GPSDataBuffer*)&gpsData,i);
  
    if(alt_alarm_start(&ledAlarm,LED_TICKS,LEDTick,0) < 0)
    {
        alt_putstr("No system clock available.\n");
    }

    /* Event loop never exits. */
    while (1)
    {
    }

    return 0;
}

void ControlEval(alt_u8 byte)
{
    switch(controlState)
    {
    case CONTROL_STATE_B0:
        if(byte==CONTROL_B0)controlState=CONTROL_STATE_B1;
        break;
    case CONTROL_STATE_B1:
        if(byte==CONTROL_B1)controlState=CONTROL_STATE_CMD;
        else controlState=CONTROL_STATE_B0;
        break;
    case CONTROL_STATE_CMD:
        controlCommand=byte;
        controlState=CONTROL_STATE_LEN0;
        ControlEvalCommand();
        break;
    case CONTROL_STATE_LEN0:
        controlLength=((alt_u16)byte)<<8;
        controlState=CONTROL_STATE_LEN1;
        break;
    case CONTROL_STATE_LEN1:
        controlLength|=byte;
        controlState=CONTROL_STATE_PAYLOAD;
        if(controlLength==0)controlState=CONTROL_STATE_B0;
        controlBytesRead=0;
        break;
    case CONTROL_STATE_PAYLOAD:
        ControlEvalPayload(byte);
        if(++controlBytesRead==controlLength)
        {
            controlState=CONTROL_STATE_B0;
            alt_printf("Received 0x%x bytes.\n",controlBytesRead);
        }
        break;
    }
}

void ControlEvalCommand()
{
    switch(controlCommand)
    {
    case CONTROL_CMD_RESET_FEED:
        alt_putstr("Resetting feed.\n");
        gpsData.readIndex=0;
        gpsData.readOffset=0;
        gpsData.readWord=0;
        controlState=CONTROL_STATE_B0;
        break;
    case CONTROL_CMD_START_FEED:
        alt_putstr("Starting feed.\n");
        gpsDataOut&=~GPS_DATA_CLOCK;
        IOWR_ALTERA_AVALON_PIO_DATA(GPS_DATA_BASE,gpsDataOut);
        alt_alarm_start(&dataAlarm,DATA_TICKS,DataTick,0);
        controlState=CONTROL_STATE_B0;
        break;
    case CONTROL_CMD_STOP_FEED:
        alt_putstr("Stopping feed.\n");
        alt_alarm_stop(&dataAlarm);
        controlState=CONTROL_STATE_B0;
        break;
    default: break;
    }
}

void ControlEvalPayload(alt_u8 byte)
{
    switch(controlCommand)
    {
    case CONTROL_CMD_DOWNLOAD:
        if(controlBytesRead==0)InitializeBuffer((GPSDataBuffer*)&gpsData,NULL);
        WriteGPSByte((GPSDataBuffer*)&gpsData,byte);
        break;
    case CONTROL_CMD_DOWNLOAD_WORD:
        if(controlBytesRead==0)InitializeBuffer((GPSDataBuffer*)&gpsData,NULL);
        WriteGPSWord((GPSDataBuffer*)&gpsData,byte);
        break;
    default: break;
    }
}

void InitializeBuffer(GPSDataBuffer* buffer, alt_u8 *address)
{
    if(buffer==NULL)return;
    
    if(address!=NULL)buffer->data=address;
    buffer->numWords=0;
    
    buffer->readIndex=0;
    buffer->readOffset=0;
    buffer->readWord=0;
    
    buffer->writeIndex=0;
    buffer->writeOffset=0;
    buffer->writeWord=0;
}

alt_u8 ReadGPSWord(GPSDataBuffer *buffer, alt_u8 *value)
{
    alt_u8 spillMask, spillShift;
    
    (*value)=(buffer->data[buffer->readIndex]>>buffer->readOffset)&0x07;
    
    buffer->readOffset+=3;
    if(buffer->readOffset>=8)
    {
        buffer->readOffset-=8;
        buffer->readIndex++;
        if(buffer->readOffset>0)
        {
            spillMask=(1<<buffer->readOffset)-1;
            spillShift=3-buffer->readOffset;
            (*value)|=(buffer->data[buffer->readIndex]&spillMask)<<spillShift;
        }
    }
    
    if(++buffer->readWord==buffer->numWords)
    {
        buffer->readIndex=0;
        buffer->readOffset=0;
        buffer->readWord=0;
        return 0;
    }
    else return 1;
}

void WriteGPSWord(GPSDataBuffer *buffer, alt_u8 value)
{
    alt_u8 word;
    
    word=buffer->data[buffer->writeIndex]&((1<<buffer->writeOffset)-1);
    word|=(value<<buffer->writeOffset)&0xFF;
    buffer->data[buffer->writeIndex]=word;
    
    buffer->writeOffset+=3;
    if(buffer->writeOffset>=8)
    {
        buffer->writeOffset-=8;
        buffer->writeIndex++;
        if(buffer->writeOffset>0)
        {
            value>>=(3-buffer->writeOffset);
            buffer->data[buffer->writeIndex]=value;
        }
    }
    
    buffer->numWords++;
}

void WriteGPSByte(GPSDataBuffer *buffer, alt_u8 value)
{
    buffer->data[buffer->writeIndex]=value;
    buffer->writeIndex++;
    switch(buffer->writeOffset)
    {
    case 0:
        buffer->numWords+=2;
        buffer->writeOffset=6;
        break;
    case 6:
        buffer->numWords+=3;
        buffer->writeOffset=7;
        break;
    case 7:
        buffer->numWords+=3;
        buffer->writeOffset=0;
        break;
    default:
        buffer->numWords+=2;
        buffer->writeOffset=6;
        break;
    }
}
