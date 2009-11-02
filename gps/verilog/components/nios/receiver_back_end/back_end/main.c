#include <alt_types.h>
#include <altera_avalon_pio_regs.h>
#include <altera_avalon_uart_regs.h>
#include <sys/alt_irq.h>
#include <sys/alt_alarm.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include "system.h"

typedef struct
{
    alt_32 i_prompt;
    alt_32 q_prompt;
    alt_32 w_df;
    alt_32 w_df_dot;
    alt_32 doppler_dphi;
    alt_32 ca_dphi;
} Tracking;

int heartbeat_led;
static alt_alarm heartbeat_alarm;

volatile alt_u8 update_ready;
volatile Tracking tracking_params;

alt_u32 Heartbeat(void *context)
{
    //Toggle heartbeat LED.
    heartbeat_led=~heartbeat_led;
    IOWR_ALTERA_AVALON_PIO_DATA(HEARTBEAT_LED_BASE,heartbeat_led);
    return alt_ticks_per_second();
}

inline void SignFix32(volatile alt_32 *value, alt_u8 width)
{
    if((*value)&(1<<(width-1)))
    {
        (*value)|=~((1<<width)-1);
    }
}

void TrackingUpdate(void *context, alt_u32 id)
{
    //Read tracking parameters.
    tracking_params.i_prompt=IORD_ALTERA_AVALON_PIO_DATA(I_PROMPT_BASE);
    tracking_params.q_prompt=IORD_ALTERA_AVALON_PIO_DATA(Q_PROMPT_BASE);
    tracking_params.w_df=IORD_ALTERA_AVALON_PIO_DATA(W_DF_BASE);
    tracking_params.w_df_dot=IORD_ALTERA_AVALON_PIO_DATA(W_DF_DOT_BASE);
    tracking_params.doppler_dphi=IORD_ALTERA_AVALON_PIO_DATA(DOPPLER_DPHI_BASE);
    tracking_params.ca_dphi=IORD_ALTERA_AVALON_PIO_DATA(CA_DPHI_BASE);
    update_ready=1;
    
    //Correct signed values.
    SignFix32(&tracking_params.i_prompt,I_PROMPT_DATA_WIDTH);
    SignFix32(&tracking_params.q_prompt,Q_PROMPT_DATA_WIDTH);
    SignFix32(&tracking_params.w_df,W_DF_DATA_WIDTH);
    SignFix32(&tracking_params.w_df_dot,W_DF_DOT_DATA_WIDTH);
    SignFix32(&tracking_params.doppler_dphi,DOPPLER_DPHI_DATA_WIDTH);
    SignFix32(&tracking_params.ca_dphi,CA_DPHI_DATA_WIDTH);

    //Reset interrupt flag.
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x01);
}

int main(void)
{
    int uart_fd;
    char data[100];
    
    update_ready=0;
    data[0]=0xDE;
    data[1]=0xAD;
    data[2]=0xBE;
    data[3]=0xEF;
    
    heartbeat_led=0;

    //Open UART for update TX.
    uart_fd=open("/dev/uart_0",O_RDWR,0);

    //Enable tracking update interrupt.
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x01);
    alt_irq_register(TRACKING_READY_IRQ,NULL,TrackingUpdate);

    //Enable heartbeat timer.
    alt_alarm_start(&heartbeat_alarm,alt_ticks_per_second(),Heartbeat,0);

    while(1)
    {
        if(update_ready)
        {
            update_ready=0;

            /*sprintf(data,"Update: i=%d, q=%d, w=%d, w_dot=%d, dopp_dphi=%d.",
                   (int)tracking_params.i_prompt,
                   (int)tracking_params.q_prompt,
                   (int)tracking_params.w_df,
                   (int)tracking_params.w_df_dot,
                   (int)tracking_params.doppler_dphi);*/

            //Send tracking parameters.
            memcpy(data+4,(const void*)&tracking_params,sizeof(tracking_params));
            write(uart_fd,(const void*)data,sizeof(tracking_params)+4);
            //write(uart_fd,(const void*)data,strlen(data));
            //puts((const void*)data);
        }
    }
    
    return 0;
}
