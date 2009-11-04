function w_plot(data)
CARRIER_ACC_WIDTH=27;
F_S=16.8e6;
ANGLE_SHIFT=9;

w_df=data(:,1);
w_df_dot=data(:,2);
dopp_dphi=data(:,3);

f_df=w_df/2/pi/2^ANGLE_SHIFT;
f_dphi=dopp_dphi*F_S/2^CARRIER_ACC_WIDTH;

figure('Name','Doppler Shift Plot','Numbertitle','off');

subplot(2,1,1);
hold on;
plot(f_df,'b');
plot(f_dphi,'g');
plot(smooth(f_df,15,'loess'),'--r');
hold off;
title('Doppler Shift Plot');
xlabel('Time (ms)');
ylabel('Doppler Shift (Hz)');
legend('w_df','dphi','w_df_avg');

subplot(2,1,2);
plot(w_df_dot/2/pi/2^ANGLE_SHIFT,'r');
title('Doppler Rate Plot');
xlabel('Time (ms)');
ylabel('Doppler Rate (Hz/s)');

return;