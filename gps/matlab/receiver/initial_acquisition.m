function  [doppler_frequency, code_start_time, CNR] = initial_acquisition(in_sig, CAcode)
%function  [doppler_frequency, code_start_time, CNR] = INITIAL_ACQUISITION(in_sig, CAcode)
%
% This function will take as input:
%
% Input               Description
% in_sig              the input signal
% CAcode              the CA code for the current satellite
%                     from GPS_SW_RCX.m
%
% The function will then conduct a rough doppler frequency search for the satellite specified over
% -FD_SIZE:FREQ_STEP:FD_SIZE (CONSTANT.m).  If a signal is found, the code will then determine
% the time delay from the beginning of in_sig to the point where the signal
% is found.
%
% The outputs are:
%
% If no satellite is found:
% Output              Description
% doppler_frequency   Will default to 0
% code_start_time     Will default to -1
% CNR                 The highest carrier-to-noise ratio found in the signal for that PRN
%
% If a satellite is found:
% Output              Description
% doppler_frequency   the rough doppler frequency in bins determined by
%                     FREQ_STEP in CONSTANT.m
% code_start_time     the absolute time delay from the beginning of in_sig
%                     to the CA Code to a precision of TP
% CNR                 the carrier-to-noise ratio of the signal found
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu), Mike Muccio (mtm15@cornell.edu)
% modified Jan. 2008 by Brady O'Hanlon (bwo1@cornell.edu)
% Copyright 2008, Cornell University, Electrical and Computer Engineering, Ithaca, NY 14850
constant_h;

%pick coherent integration time
Tacc=1;
%Bring in Tacc+1 msec of input data
in_sig_2ms = in_sig(1:ONE_MSEC_SAM*(Tacc+1));
CAcode = digitize_ca_prompt(CAcode,Tacc);
clear CAcodeTemp

%generate time base at 175nsec spacing
time = [0:1:length(in_sig_2ms)-1]'.*TP;  

corr_len = 2*length(in_sig_2ms)-1; 

%initialize vectors for speed
Icacorr = zeros(corr_len,1);   
Qcacorr = zeros(corr_len,1);    
I2Q2 = zeros(corr_len,FREQ_BINS);

%Keep running tally of maximum values for later use
max_val = [0 0 0];  

%Cycle through all possible doppler shifts from -10kHz to +10kHz and run
%xcorr at each doppler shift in the I & Q channels in order to find the
%highest correlation peak.  The frequency bin where the highest correlation
%peak occurs is the doppler frequency where the satellite was found, and
%the index of the xcorrelation indicates the time offset from the beginning
%of in_sig_3ms to where the CA code is found.
%Step over +/- FD_SIZE in doppler shifts
for fd=-FD_SIZE:FREQ_STEP:FD_SIZE           
    
    %frequency argument for upmodulation
    freq_argument = 2*pi*(FC-fd)*time;      
    
    %column number for faster data processing
    freq_bin = (fd+FD_SIZE)/FREQ_STEP+1;    
    
    %demod at current doppler shift
    Si = in_sig_2ms.*AMP.*cos(freq_argument); 
    
    %and get out the I and Q factors
    Sq = -in_sig_2ms.*AMP.*sin(freq_argument);
    
    %Do the cross correlations to get the values
    Icacorr = xcorr(Si,CAcode); 
    Qcacorr = xcorr(Sq,CAcode); 
    
    %determine index and power for this doppler frequency at which the
    %maximum signal power was detected
    I2Q2(:,freq_bin) = (Icacorr.^2 + Qcacorr.^2);
    [y,i] = max(abs(I2Q2(:,freq_bin)));
    %does the current maximum power exceed the running maximum power?
    if(max_val(2)<y)
        %if so, replace the value
        max_val = [fd, y, i];    %these are the doppler, max power, index
    end                                 
end  

%if the CNR < CNO_MIN, set cst to invalid value
CNR=10*log10(((max_val(2)/(SNR_FLOOR*(Tacc)))-1)/(.001*(Tacc)));
if(CNR<CNO_MIN)   
    code_start_time = -1;
    doppler_frequency = 0;
else
    doppler_frequency = max_val(1);

    tRewind = (FSAMP_MSEC*(Tacc))/(1+doppler_frequency/L1);
    %have to account for xcorr output length and non-zero indexing
    code_start_time = (max_val(3)-tRewind)*TP;

end
return;
