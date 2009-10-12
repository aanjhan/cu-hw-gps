function [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1, w_df_dot_kp1] = flldll_fixed(I_prompt_k, Q_prompt_k,...
    I_early_k, Q_early_k, I_late_k, Q_late_k, w_df_k, w_df_dot_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1)
% function [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1, w_df_dot_kp1] = FLLDLL(I_prompt_k, Q_prompt_k,...
%     I_early_k, Q_early_k, I_late_k, Q_late_k, w_df_k, w_df_dot_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1)
%
% This function will take as input:
%
% Input               Description
% I_prompt_k          The current I prompt value as calculated in CA_CORRELATOR.m
% Q_prompt_k          The current Q prompt value as calculated in CA_CORRELATOR.m
% I_early_k           The current I early value as calculated in CA_CORRELATOR.m
% Q_early_k           The current Q early value as calculated in CA_CORRELATOR.m
% I_late_k            The current I late value as calculated in CA_correaltor.m
% Q_late_k            The current Q late value as calculated in CA_correlator.m
% w_df_k              The current doppler frequency estimate
% w_df_dot_k          The current doppler frequency rate estimate
% I_prompt_km1        The previous iteration I_prompt value
% Q_prompt_km1        The previous iteration Q_prompt value
% CNo_k               The current I^2+Q^2
% CNo_km1             The previous I^2+Q^2
%
% The function then computes how much the CA code is drifting, and calculates the next iteration chipping rate.
% The function also computes the next doppler shift estimate for CA_CORRELATOR, and indirectly, the phase offset
% estimate, also used for CA_CORREALTOR.  The value error_bias_k is used to extract the bits.
% 
% The outputs are:
% 
% Output              Description
% chip_rate_kp1       The next iteration chipping rate used to calculate the next code start time
% err_phs_k           The current iteration phase estimate
% err_code_k          The current iteration code error estimate
% w_df_kp1            The next iteration doppler frequency
% w_df_dot_kp1        The next iteration doppler frequency rate
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu) (partially adapted from
%PLLDLL.m)
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853
constant_h;
%Obtain magnitude of early and late I and Q vectors used for DLL
IQearly = sqrt(I_early_k^2+Q_early_k^2);
IQlate  = sqrt(I_late_k^2+Q_late_k^2);

%This is the phase error
err_phs_k = -atan(Q_prompt_k/I_prompt_k);

%Determine the amplitude of the peak
amplitude = (IQearly+IQlate)/(2-CHIPS_EML);
%Get the shift in chips necessary to re-center the triangle
tau_prime = (IQearly-IQlate)/2/amplitude;
%and the code phase error
err_code_k = tau_prime*NUM_CHIPS;

[w_df_kp1,w_df_dot_kp1]=fll_fixed(I_prompt_k, Q_prompt_k,...
                                  w_df_k, w_df_dot_k,...
                                  I_prompt_km1, Q_prompt_km1,...
                                  CNo_k, CNo_km1);

%
%  Do the code tracking DLL calculations with doppler aiding 
%
chip_rate_kp1 = CA_FREQ*(1+HNUM*tau_prime+w_df_kp1/2/pi/L1);

return;
