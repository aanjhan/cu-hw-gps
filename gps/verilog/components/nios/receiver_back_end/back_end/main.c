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
    alt_32 tau_prime;
    alt_u32 i2q2_early;
    alt_u32 i2q2_prompt;
    alt_u32 i2q2_late;
} Tracking;

int heartbeat_led;
static alt_alarm heartbeat_alarm;

volatile alt_u8 updates_ready;
volatile Tracking tracking_params[4];
volatile int param_head;
int param_tail;

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
        (*value)|=~((1<<(alt_u32)width)-1);
    }
}

void TrackingUpdate(void *context, alt_u32 id)
{
    volatile Tracking *params;
    
    //IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x00);

    //Reset interrupt flag.
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x01);
        
    params=&tracking_params[param_head];
    if(++param_head>3)param_head=0;
    
    //Read tracking parameters.
    params->i_prompt=IORD_ALTERA_AVALON_PIO_DATA(I_PROMPT_BASE);
    params->q_prompt=IORD_ALTERA_AVALON_PIO_DATA(Q_PROMPT_BASE);
    params->w_df=IORD_ALTERA_AVALON_PIO_DATA(W_DF_BASE);
    params->w_df_dot=IORD_ALTERA_AVALON_PIO_DATA(W_DF_DOT_BASE);
    params->doppler_dphi=IORD_ALTERA_AVALON_PIO_DATA(DOPPLER_DPHI_BASE);
    params->ca_dphi=IORD_ALTERA_AVALON_PIO_DATA(CA_DPHI_BASE);
    params->tau_prime=IORD_ALTERA_AVALON_PIO_DATA(TAU_PRIME_BASE);
    params->i2q2_early=IORD_ALTERA_AVALON_PIO_DATA(I2Q2_EARLY_BASE);
    params->i2q2_prompt=IORD_ALTERA_AVALON_PIO_DATA(I2Q2_PROMPT_BASE);
    params->i2q2_late=IORD_ALTERA_AVALON_PIO_DATA(I2Q2_LATE_BASE);
    
    //Correct signed values.
    SignFix32(&params->i_prompt,I_PROMPT_DATA_WIDTH);
    SignFix32(&params->q_prompt,Q_PROMPT_DATA_WIDTH);
    SignFix32(&params->w_df,W_DF_DATA_WIDTH);
    SignFix32(&params->w_df_dot,W_DF_DOT_DATA_WIDTH);
    SignFix32(&params->doppler_dphi,DOPPLER_DPHI_DATA_WIDTH);
    SignFix32(&params->ca_dphi,CA_DPHI_DATA_WIDTH);
    
    if(updates_ready<4)++updates_ready;
    
    //IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x01);
}

int main(void)
{
    int uart_fd;
    char data[100];
    int bad_count=0;
    
    int prev_ready=0;
    
    updates_ready=0;
    data[0]=0xDE;
    data[1]=0xAD;
    data[2]=0xBE;
    data[3]=0xEF;
    
    heartbeat_led=0;
    
    param_head=0;
    param_tail=0;

    //Open UART for update TX.
    uart_fd=open("/dev/uart_0",O_RDWR,0);

    //Enable tracking update interrupt.
    //IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x01);
    //alt_irq_register(TRACKING_READY_IRQ,NULL,TrackingUpdate);

    //Enable heartbeat timer.
    alt_alarm_start(&heartbeat_alarm,alt_ticks_per_second(),Heartbeat,0);

    while(1)
    {
        /*if(IORD_ALTERA_AVALON_PIO_DATA(TRACKING_READY_BASE))
        {
            if(!prev_ready)
            {
                prev_ready=1;
                TrackingUpdate(0,0);
                printf("Edge\n");
            }
        }
        else prev_ready=0;*/
        if(IORD_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE))
        {
            TrackingUpdate(0,0);
            //printf("Edge\n");
        }
        
        if(updates_ready)
        {
            /*sprintf(data,"Update: i=%d, q=%d, w=%d, w_dot=%d, dopp_dphi=%d.",
                   (int)tracking_params.i_prompt,
                   (int)tracking_params.q_prompt,
                   (int)tracking_params.w_df,
                   (int)tracking_params.w_df_dot,
                   (int)tracking_params.doppler_dphi);*/

            //Send tracking parameters.
            memcpy(data+4,(const void*)&tracking_params[param_tail],sizeof(Tracking));
            write(uart_fd,(const void*)data,sizeof(Tracking)+4);
            
            /*if(tracking_params[param_tail].doppler_dphi>100000)
            {
                printf("Bad: %d\n",tracking_params[param_tail].doppler_dphi);
            }*/
            if(++param_tail>3)param_tail=0;
            updates_ready--;
            //write(uart_fd,(const void*)data,strlen(data));
            //puts((const void*)data);
        }
    }
    
    return 0;
}
