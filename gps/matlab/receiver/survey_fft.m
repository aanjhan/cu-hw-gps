function  [doppler_frequency, code_start_time, CNR, I2Q2] = survey(in_sig, PRN, codeLength, startTime)
%function  [doppler_frequency, code_start_time, CNR, I2Q2] = SURVEY(in_sig, PRN)
%
% This function will take as input:
%
% Input               Description
% in_sig              at least 2 ms of the input signal
% PRN                the satellite vehicle ID we are currently searching for
%
% This function requires variables from CONSTANT.m 
%
% The function will then conduct a rough doppler frequency search for the satellite specified over
% -FD_SIZE:FREQ_STEP:FD_SIZE (CONSTANT.m).  If a signal is found, the code will then determine
% the rough time delay from the beginning of in_sig to the closest sample.
%
% Output              Description
% doppler_frequency   the rough doppler frequency
% code_start_time     the absolute time delay from the beginning of in_sig to the CA Code start time
% CNR                 the carrier-to-noise ratio of the signal found
% I2Q2                I^2+Q^2 output of correlation between incoming signal
%                     and the locally generated signal.  It's an array
%                     arranged by the correlation delay (rows) and the
%                     doppler (columns).
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu), Mike Muccio (mtm15@cornell.edu)
% Copyright 2002, Cornell University, Electrical and Computer Engineering, Ithaca, NY 14850

constant_rcx;

if(nargin<3) codeLength = 2; end
if(nargin<4) startTime = 0; end

global DoppToBinIndex;
DoppToBinIndex=@(fd) (fd+FD_SIZE)/FREQ_STEP+1;

sigOffset=floor(startTime*ONE_MSEC_SAM);
in_sig_2ms = in_sig(sigOffset+(1:floor((codeLength*2)*ONE_MSEC_SAM)));      %Use only 2 msec of input data

%create the upsampled CA Code for this specific satellite
CAcode = digitize_ca_prompt(cacodegn(PRN),codeLength);
Cr = fft([zeros(length(CAcode),1); CAcode]);

%generate time vector at 175nsec spacing for baseband mixing
time = [0:1:length(in_sig_2ms)-1]'.*TP;   

%corr_len = 2*length(in_sig_2ms)-1;
corr_len = length(in_sig_2ms*2);

%create the 2-D matrix of I/Qcacorr for xcorr speed
Icacorr = zeros(corr_len,FREQ_BINS);    
Qcacorr = zeros(corr_len,FREQ_BINS);
I2Q2 = zeros(corr_len,FREQ_BINS);

%Keep running tally of maximum values for later use
max_val = [0 0 0];

%Cycle through all possible doppler shifts from -10kHz to +10kHz and run
%xcorr at each doppler shift in the I & Q channels in order to find the
%highest correlation peak.  The frequency bin where the highest correlation
%peak occurs is the doppler frequency where the satellite was found, and
%the index of the xcorrelation indicates the time offset from the beginning
%of in_sig_2ms to where the CA code is found.

%Step over +/- FD_SIZE in doppler shifts
for fd=-FD_SIZE:FREQ_STEP:FD_SIZE           
    %argument for demodulation of the signal
    freq_argument = FC+fd;
    
    %column number for faster data processing
    freq_bin = DoppToBinIndex(fd);
    
    xtilde = in_sig_2ms.*AMP.*exp(j*2*pi*freq_argument*time);
    Xr = fft(xtilde);
    Zr = Xr.*conj(Cr);
    zk = ifft(Zr);
    
    %Find I^2+Q^2
    I2Q2(:,freq_bin) = abs(zk).^2;
    
    %Find the maximum value of I^2+Q^2 and save its index
    [y,i] = max(abs(I2Q2(:,freq_bin)));
    
    %is the max value just found a global max?
    if(max_val(:,2)<y)
        %if yes, note the current doppler shift, the max value and the
        %index
        max_val = [fd, y, i];              
    end                                 
end

%now print out some results
surf(I2Q2);
CNR = 10*log10((max_val(2)-SNR_FLOOR)/SNR_FLOOR/(codeLength*1e-3));
code_start_time = max_val(3);
doppler_frequency = max_val(1);
fprintf('PRN %02d had a peak value of %f at a Doppler of %f\n',PRN,CNR,max_val(1));

return;
