function bit_k = extract_bit(theta_k, bit_km1)
% function bit_k = EXTRACT_BIT(theta_k, bit_km1)
%
% This function will take as input:
%
% Input               Description
% theta_k             Current value of theta from CARRIER_LOCK_INDICATOR
% bit_km1             Previous bit value
% 
% The function then determines if a phase transition has occured, indicating a bit flip.  If a bit transition
% has occured, the inverse bit from the previous bit (bit_km1) is recorded, otherwise the same bit is recorded.
% 
% The outputs are:
% 
% Output              Description
% bit_k               Current bit value
%
%AUTHOR(S):  Alex Cerruti (apc20@cornell.edu)
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853

%check to see if the phase has flipped by looking at the magnitude of
%the angle, theta_k
if(abs(theta_k)>pi/2)
    %if it has, flip the current bit from the previous bit
    bit_k = 1-bit_km1;
else
    %otherwise the bit is the same as the previous bit
    bit_k = bit_km1;  
end;

return;