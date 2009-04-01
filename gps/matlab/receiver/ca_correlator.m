function [I_prompt_kp1, Q_prompt_kp1, I_early_kp1, Q_early_kp1, I_late_kp1, Q_late_kp1]...
    = ca_correlator(code_start_time_k, in_sig, ...
    w_if_k, SV_offset_CA_code, E_CA_code, L_CA_code, phi_if_k, t0)
% function [I_prompt_kp1, Q_prompt_kp1, I_early_kp1, Q_early_kp1, I_late_kp1, Q_late_kp1]...
%     = CA_CORRELATOR(code_start_time_k, PRN, in_sig, ...
%     w_if_k, SV_offset_CA_code, E_CA_code, L_CA_code, phi_if_k, t0)
%
% This function will take as input:
%
% Input               Description
% code_start_time_k   The C/A code start time for the current iteration
% in_sig              The input signal of raw data bits (+/-1 & +/-3 format)
% w_if_k              The intermediate frequency for the current iteration (w_fc_k - w_df_k)
% phi_if_k            The intermediate frequency phase offset for the current iteration
% t0                  The time offset from the beginning of the current
%                     file to the initial file, used for seamless, multi-file access
% offset_CA_code      The upsampled prompt C/A code
% E_CA_code           The upsampled early C/A Code
% L_CA_code           The upsampled late C/A code
%
% This program requires certain globals defined in CONSTANT_RCX.m
%
% The function will then base-band mix the input signal starting the the code_start_time_k using
% w_if_k, phi_if_k, and t0.  The demodulated In- and quad- phase signal is then correlated with
% the previously generated SV_offset_CA_code, E_CA_code, and L_CA_code to generate I/Q Prompt,
% I/Q Early, and I/Q Late respectively.
%
% The outputs are:
%
% Output              Description
% I_prompt_kp1        The In-phase prompt value
% Q_prompt_kp1        The Quad-phase prompt value
% I_early_kp1         The In-phase early value
% Q_early_kp1         The Quad-phase early value
% I_late_kp1          The In-phase late value
% Q_late_kp1          The Quad-phase late value
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), Mike Muccio (mtm15@cornell.edu)
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853
constant_h;

%Subtract the start time of current data file
%to get the proper index into the file
code_start_time_k = code_start_time_k-t0;

%get the index from the code_start_time_k
I = floor(code_start_time_k/TP);           

%this is the fraction of a sample we are off (in seconds)
tau = code_start_time_k - I*TP; 

time_offset_index = round(tau/T_RES);
if(time_offset_index==14)
    I = I+1;
    time_offset_index=0;
end
Prompt_CA = SV_offset_CA_code(:,1+time_offset_index);
Early_CA = E_CA_code(:,1+time_offset_index);
Late_CA = L_CA_code(:,1+time_offset_index);

%Create the sampling vector
samp_index = I:I+ONE_MSEC_SAM-1;

%And the time and freq. vectors for baseband mixing
time = (samp_index*TP-code_start_time_k)';
freq_arg = w_if_k*time+phi_if_k;

%generate 1 msec. w/ 1*5714 samples for
%CA code and sine wave mixing
%note that modulationsin is NEGATIVE because of aliasing
modulationcos = AMP*cos(freq_arg);   
modulationsin = -AMP*sin(freq_arg);

%baseband mix the signal with I and Q local carrier replicas
IC = in_sig(samp_index+1).*modulationcos;
QC = in_sig(samp_index+1).*modulationsin;
%mix IC, QC with E, P, and L codes and accumulate
I_prompt_kp1 = sum(IC.*Prompt_CA);
Q_prompt_kp1 = sum(QC.*Prompt_CA);
I_early_kp1 = sum(IC.*Early_CA);
Q_early_kp1 = sum(QC.*Early_CA);
I_late_kp1 = sum(IC.*Late_CA);
Q_late_kp1 = sum(QC.*Late_CA);

return;