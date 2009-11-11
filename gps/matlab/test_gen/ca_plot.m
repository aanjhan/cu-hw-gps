function ca_plot(data)
CA_ACC_WIDTH=25;
F_S=16.8e6;

figure('Name','Code Rate Plot','Numbertitle','off');
plot(data*F_S/2^CA_ACC_WIDTH);
set(title('Code Chipping Rate'),'FontSize',14);
set(xlabel('Time (ms)'),'FontSize',14);
set(ylabel('\Deltaf_{chip} (Hz)'),'FontSize',14);

return;