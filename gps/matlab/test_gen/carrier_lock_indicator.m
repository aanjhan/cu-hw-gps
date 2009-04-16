function [carrier_lock_k, theta_k] = carrier_lock_indicator(I_prompt_k, Q_prompt_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1)
%function [carrier_lock_k, theta_k] = CARRIER_LOCK_INDICATOR(I_prompt_k, Q_prompt_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1)
%
% This function will take as input:
%
% Input               Description
% I_prompt_k          The current I prompt value as calculated in CA_CORRELATOR
% Q_prompt_k          The current Q prompt value as calculated in CA_CORRELATOR
% I_prompt_km1        The previous I prompt value as calculated in CA_CORRELATOR
% Q_prompt_km1        The previous Q prompt value as calculated in CA_CORRELATOR
% CNo_k               The current Carrier/Noise ratio
% CNo_km1             The previous Carrier/Noise ratio
%
% The dot product between [I_prompt_k Q_prompt_k] and [I_prompt_km1 Q_prompt_km1]
% is determined.  The angle is then compared to CARRIER_THRESHOLD for lock indication
%
% The outputs are:
%
% Output              Description
% carrier_lock_k      The lock indicator for the current iteration, High (1) for lock, else low (0) for no lock
% theta_k             The measured angle.  theta_k is later used for data bit demodulation
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu)
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853
CONSTANT_H;

%Carrier lock for FLL and PLL: determine the angle using the
%normalized dot product
theta_k = acos((I_prompt_k*I_prompt_km1+Q_prompt_k*Q_prompt_km1)/(sqrt(CNo_k*CNo_km1)));

%and compare this value to the threshold
if(abs(theta_k) < CARRIER_THRESHOLD || abs(theta_k-pi) < CARRIER_THRESHOLD)
    carrier_lock_k = 1;
else
    carrier_lock_k = 0;
end

return