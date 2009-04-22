function gps_sw_rcx()
%
% The purpose of this script is to acquire and track GPS satellite signals
% in non-real time from a digitzed data source.  It is also capable of
% providing a navigation solution from the data sets generated in this
% program.
%
% The following m files are required for this program to run:
% BIT_LOCK.m
% CA_CORRELATOR.m
% CACODEGN.m
% CARRIER_LOCK_INDICATOR.m
% constant.m - navigation constants (i.e., from ECE 4150)
% CONSTANT_H.m - declares CONSTANT_RCX values global
% CONSTANT_RCX.m - receiver constants
% DIGITIZE_CA.m
% ecef.m - from 415
% EXTRACT_BIT.m
% EXTRACT_EPHEM.m
% findsat.m - from 415
% FRAME_LOCK.m
% INITIAL_ACQUISITION.m
% latlong.m - from 415
% LOAD_GPS_DATA.m (which requires convertbitpack2bit1.c)
% MAT2INT.m
% PARITY_CHECK.m
% PLLDLL.m
% printnav.m - from 415
% PSEUDO_EPHEM.m
% pseudocaion.m - from 415
% SIGNAL_TRACKING.m
% solveposod.m - from 415
% TWOSCOMP2DEC.m
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu), Bryan Galusha
% (btg3@cornell.edu), Jeanette Lukito (jl259@cornell.edu), Mike Muccio
% (mtm15@cornell.edu), Paul Kintner (paul@ece.cornell.edu), Brady O'Hanlon
% (bwo1@cornell.edu)
% Copyright 2009, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853

% Call the constants
constant_h;
constant_rcx;
PRN = [];
choose = 0;
while(choose ~= 1 && choose ~= 2 && choose ~= 3 && choose ~= 4)
    fprintf('Would you like to:\n1) Track 1 or more satellites\n2) Obtain the navigation solution\n3) Extract almanac\n4) Quit\n')
    choose = input(': ');
end

if(choose == 4)
    return;
elseif(choose == 1)
    PRNflag = 1;
    while(PRNflag)
        PRN = input('\nPlease enter one or more satellites to track in the form [SV1 SV2 ...]\n  or press enter to search for all satellites: ');
        if(isempty(PRN))
            PRN = 1:32;
            PRNflag =0;
        else
            PRNflag = 0;
        end
    end

    %the file name of the digitized data
    file = input('\nEnter the digitized data file name: ','s');

    %the number of seconds to track the signal for
    Nfiles = input('\nEnter the number of seconds to track the signal for: ');

    %load the data by calling LOAD_GPS_DATA
    %skip ahead seconds in the data if desired by setting second loop arg
    % and uncommenting this loop
    %for x= 1:10
    %    [in_sig, fid, fileNo] = load_gps_data(file,0,1);
    %end
    tic
    for x=1:length(PRN)
        %load 1 sec. of data from file
        [in_sig, fid, fileNo] = load_gps_data(file,0,1);
        
        %generate CA code for the particular satellite, and then again for each time_offset,
        %and again at each time offset for each early and late CA code
        %initialize arrays for speed
        SV_offset_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
        E_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
        L_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
        %and obtain the CA code for this particular satellite
        current_CA_code = sign(cacodegn(PRN(x))-0.5);
        %loop through all possible offsets to gen. CA_Code w/ offset
        for time_offset = 0:T_RES:TP-T_RES       
            [SV_offset_CA_code(:,1 + round(time_offset/T_RES)) ...
                E_CA_code(:,1 + round(time_offset/T_RES)) ...
                L_CA_code(:,1 + round(time_offset/T_RES))] ...
                = digitize_ca(-time_offset,current_CA_code);
        end
        
        %call FFT_ACQUISITION to estimate the doppler frequency and
        %code start time if flag set in constant
        if(USE_FFT==1)
            [doppler_frequency, code_start_time, CNR] = fft_acquisition(in_sig,current_CA_code);
        else
            %otherwise use normal acquisition routine 
            [doppler_frequency, code_start_time, CNR] = initial_acquisition(in_sig,current_CA_code);
        end
        
        %if the signal was not found, quit this satellite
        if(CNR<CNO_MIN || code_start_time < 0)  
            fprintf('Warning: Initial Acquisition failed: PRN %02d not found in data set\n',PRN(x))
            fprintf('Doppler Frequency: %d   Code Start Time: %f    CNR: %f\n',doppler_frequency, code_start_time, CNR);
        %otherwise track the satellite
        else 
            fprintf('PRN %d Found: Doppler Frequency: %d, CNR = %04.2f\n',PRN(x), doppler_frequency, CNR);
            %perform SIGNAL_TRACKING which will track the satellite and
            %determine the bits later used for the navigation solution
            signal_tracking(doppler_frequency, code_start_time, in_sig, PRN(x), SV_offset_CA_code,...
                E_CA_code, L_CA_code, fid, file, fileNo, Nfiles);
            if(fid~=-1)
                fclose(fid);
            end
        end
    end
    toc
elseif(choose == 2)
    svids = input('Please enter satellites to obtain\n navigation solution: ');
    period = input('Please enter sampling period (ie 50 gives 1 sec solutions)\n to obtain Nav Soln / PR measurements: ');
    pseudo_ephem(svids,period)
elseif(choose == 3)
    svid = input('Please enter the satellite from which to obtain the almanac: ');
    process_almanac(svid);
end

return
