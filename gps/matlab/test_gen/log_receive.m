function log=log_receive(device_name,display)
global running;

if(nargin<2)
    display=0;
end

figure('Name','Log Receiver','Numbertitle','off');
btn=uicontrol('style','pushbutton',...
    'string','Stop!',...
    'callback','global running;running=0;clear running;close');

%Setup display.
CARRIER_ACC_WIDTH=27;
F_S=16.8e6;
ANGLE_SHIFT=9;
hist_size=100;
if(display)
    iq=zeros(hist_size,2);
    subplot(2,2,[1 3]);
    h_iq=plot(iq(:,1),iq(:,2),'x');
    h_ax_iq=gca;
    axis_limit=0;
    title('I/Q Accumulation Plot');
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    axis square;
    
    t=zeros(hist_size,1);
    
    subplot(2,2,2);
    w_df=zeros(hist_size,1);
    dopp_dphi=zeros(hist_size,1);
    hold on;
    h_w_df=plot(t,w_df*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT));
    h_dopp_dphi=plot(t,dopp_dphi*F_S/2^CARRIER_ACC_WIDTH,'g');
    hold off;
    title('Doppler Shift Plot');
    xlabel('Time (ms)');
    ylabel('Doppler Shift (Hz)');
    
    subplot(2,2,4);
    w_df_dot=zeros(hist_size,1);
    h_w_df_dot=plot(w_df_dot*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT),'r');
    title('Doppler Rate Plot');
    xlabel('Time (ms)');
    ylabel('Doppler Rate (Hz/s)');
end

numValues=10;
data=zeros(1,numValues);

device=serial_open(device_name);

%Disable timeout warning.
warning off MATLAB:serial:fread:unsuccessfulRead;

running=1;
log=[];
state=0;
while(running==1)
    drawnow;
    
    %Start byte 0 (0xDE).
    if(state==0)
        b=serial_read(device,1,'uint8');
        if(b==hex2dec('DE'))
            state=1;
        end
    %Start byte 1 (0xAD).
    elseif(state==1)
        b=serial_read(device,1,'uint8');
        if(b==hex2dec('AD'))
            state=2;
        else
            state=0;
        end
        
        i=0;
    %Start byte 2 (0xBE).
    elseif(state==2)
        b=serial_read(device,1,'uint8');
        if(b==hex2dec('BE'))
            state=3;
        else
            state=0;
        end
        
        i=0;
    %Start byte 3 (0xEF).
    elseif(state==3)
        b=serial_read(device,1,'uint8');
        if(b==hex2dec('EF'))
            state=4;
        else
            state=0;
        end
        
        i=0;
    elseif(i<7)
        data(i+1)=serial_read(device,1,'int32');
        
        i=i+1;
    else
        data(i+1)=serial_read(device,1,'uint32');
        
        i=i+1;
        if(i==numValues)
            state=0;
            log=[log;data];
            
            if(display)
                t=[t(2:end);t(end)+1];
                
                iq=[iq(2:end,:);data(1:2)];
                set(h_iq,'XData',iq(:,1));
                set(h_iq,'YData',iq(:,2));
                axis_limit=max(max(max(abs(iq))),axis_limit);
                axis(h_ax_iq,[-axis_limit axis_limit -axis_limit axis_limit]);
                
                w_df=[w_df(2:end);data(3)];
                set(h_w_df,'XData',t);
                set(h_w_df,'YData',w_df*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT));
                
                w_df_dot=[w_df_dot(2:end);data(4)];
                set(h_w_df_dot,'XData',t);
                set(h_w_df_dot,'YData',w_df_dot*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT));
                
                dopp_dphi=[dopp_dphi(2:end);data(5)];
                set(h_dopp_dphi,'XData',t);
                set(h_dopp_dphi,'YData',dopp_dphi*F_S/2^CARRIER_ACC_WIDTH);
                
                drawnow;
            end
        end
    end
end

serial_close(device);

%Re-enable timeout warning.
warning on MATLAB:serial:fread:unsuccessfulRead;

return;