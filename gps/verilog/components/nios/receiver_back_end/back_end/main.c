#include <alt_types.h>
#include <altera_avalon_pio_regs.h>
#include <altera_avalon_uart_regs.h>
#include <sys/alt_irq.h>
#include <sys/alt_alarm.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include "system.h"

typedef struct
{
    alt_u32 i_prompt;
    alt_u32 q_prompt;
    alt_u32 w_df;
} Tracking;

int heartbeat_led;
static alt_alarm heartbeat_alarm;

volatile alt_u8 update_ready;
volatile Tracking tracking_params;

alt_u32 Heartbeat(void *context)
{
    //Toggle heartbeat LED.
    heartbeat_led=~heartbeat_led;
    IOWR_ALTERA_AVALON_PIO_DATA(HEART_BEAT_LED_BASE,heartbeat_led);
    return alt_ticks_per_second();
}

void TrackingUpdate(void *context, alt_u32 id)
{
    //Read tracking parameters.
    tracking_params.i_prompt=IORD_ALTERA_AVALON_PIO_DATA(I_PROMPT_BASE);
    tracking_params.q_prompt=IORD_ALTERA_AVALON_PIO_DATA(Q_PROMPT_BASE);
    tracking_params.w_df=IORD_ALTERA_AVALON_PIO_DATA(W_DF_BASE);
    update_ready=1;

    //Reset interrupt flag.
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x00);
}

int main(void)
{
    int uart_fd;
    
    update_ready=0;
    
    heartbeat_led=0;

    //Open UART for update TX.
    uart_fd=open("/dev/uart_0",O_RDWR,0);

    //Enable tracking update interrupt.
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(TRACKING_READY_BASE,0x01);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(TRACKING_READY_BASE,0x00);
    alt_irq_register(TRACKING_READY_IRQ,NULL,TrackingUpdate);

    //Enable heartbeat timer.
    alt_alarm_start(&heartbeat_alarm,alt_ticks_per_second(),Heartbeat,0);

    while(1)
    {
        if(update_ready)
        {
            update_ready=0;

            //Send tracking parameters.
            write(uart_fd,(const void*)&tracking_params,sizeof(tracking_params));

            printf("Update: i=%d, q=%d, w=%d\n",
                   (int)tracking_params.i_prompt,
                   (int)tracking_params.q_prompt,
                   (int)tracking_params.w_df);
        }
    }
    
    return 0;
}
