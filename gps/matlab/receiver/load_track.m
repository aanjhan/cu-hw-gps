function [ip,qp,w_df]=load_track(prn);

eval(sprintf('load PRN%d_hist_1.mat',prn));
ip=I_prompt_hist;
qp=Q_prompt_hist;
w_df=w_df_hist;

eval(sprintf('load PRN%d_hist_2.mat',prn));
ip=[ip;I_prompt_hist];
qp=[qp;Q_prompt_hist];
w_df=[w_df;w_df_hist];

disp(sprintf('Doppler: Mean=%.3f, Variance=%.3f',mean(w_df(500:end)/2/pi),var(w_df(500:end)/2/pi)));

figure;
plot(ip,qp,'.');
title(sprintf('I vs. Q - PRN %d',prn));
xlabel('I');
ylabel('Q');

figure;
plot(w_df/2/pi);
title(sprintf('Doppler Frequency - PRN %d',prn));
xlabel('Time (ms)');
ylabel('Frequency (Hz)');

end