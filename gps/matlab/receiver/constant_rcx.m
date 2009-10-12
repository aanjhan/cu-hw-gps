%CONSTANT_RCX.H
%
% This script has no inputs/outputs.  It merely defines the constants
% used in the GPS_SW_RCX modules.
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), Bryan Galusha (btg3@cornell.edu), Jeanette Lukito (jl259@cornell.edu), Mike Muccio (mtm15@cornell.edu),
%Copyright 2009, Cornell University, Electrical and Computer Engineering, Ithaca, NY 14850

 FC = 3.78e6;            %incoming center frequency
 W_FC = 2*pi*FC;
 FS = 16.8e6;
 TP = 1/FS;                         %sample spacing
 T_RES = TP/14;                     %time resolution for fine code acquisition 
 CHIP = 1e-3/1023;                    %chip duration
 MIXING_SIGN = -1; %High-side = -1, low-side = 1
 FREQ_STEP = 200;                     %Freq. steps used in searching doppler shifts (must be rationally divisable by 10000)
 FD_SIZE = 6e3;                      %magnitude of max. doppler shifts to search through
 FREQ_BINS = round(2*FD_SIZE/FREQ_STEP+1); %Number of Freq. Bins used in searching for satellites
 T_QUARTER_CHIP = CHIP/4;             %Quarter chip duration used in DLL
 FSAMP_MSEC = 1e-3*FS;                 %number of samples in 1 millisecond
 AMP = sqrt(5);                       %this is the optimal signal amplitude to demodulate the data at, statistically
 SNR_FLOOR = 80000;                   %the statistical SNR floor
 ONE_MSEC_SAM = round(FSAMP_MSEC);    %~number of samples in one millisecond of data
 NUM_CHIPS = 1023;                    %number of chips in CA code
 NUMSATS = 34;                        %total number of visible satellites including WAAS
 L1 = 10.23e6*154;                    %L1 frequency
 CA_FREQ = 1.023e6;                   %CA frequency
 CHIPS_EML = 0.5;                     %Difference in early minus late chips
 %HNUM = 3.06133302796676e-006;        %convergence rate for DLL
 HNUM=5.8651e-7;
 CNO_MIN = 38.5;                        %minimum code lock value in DB
 CNO_MIN_COUNTS = (10^(CNO_MIN/10)/1000 +1)*SNR_FLOOR; %this is min code lock value in counts
 CARRIER_THRESHOLD = pi/3;            %set the width of the clouds for carrier lock
 NBS = 22.5;                          %Bit transistion threshold...this seems to be a good value for real data
 %Following parameters are used for the PLL
 USE_PLL = 0;           % To use only the FLL, set USE_PLL = 0.  If you want to use the PLL, set this to 1
 INITIALIZE_PLL = 1;    % This is to run the initialization of km1 and km2 variables used in the PLL
 PLL_LOOP_ORDER = 2;    % This is the loop order to use for the PLL
 PLL_SWITCH_TIME = 0.8; % This is the time (in seconds) at which to switch over to the PLL, note this is determined empirically using the bandwidth of the FLL.
 PLL_BANDWIDTH = 5;    % This the PLL Bandwidth
 T = 1e-3;              % Duration of a C/A Code Period, in seconds
 USE_FFT = 0;           %To use FFT-based acquisition set this to 1
 
 if(PLL_LOOP_ORDER == 2)
    damping = 1/sqrt(2);
    wn = 8*PLL_BANDWIDTH*damping/(4*damping.^2+1);
    K_PLL = 2*damping*wn;
    A_PLL = wn.^2/K_PLL;
 else  %use third order PLL
    wn = 1.2*PLL_BANDWIDTH;
    K_PLL = 2*wn;
    A_PLL = 2*wn.^2./K_PLL;
    B_PLL = wn.^3./K_PLL;
 end
 
 %Following parameters are tuning values for the FLL
 FLL_BANDWIDTH = 10;                %bandwidth in Hz
 A_FLL = (1.89*FLL_BANDWIDTH).^2;      %DE = w_nF^2 = (1.89*B_LF)^2
 B_FLL = (sqrt(2)*1.89*FLL_BANDWIDTH); %EE = sqrt(2)*w_nF = sqrt(2)*1.89*B_LF


 DEBUGFLAG = 1;

%test