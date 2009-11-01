function signal_tracking(doppler_frequency, code_start_time, in_sig, PRN,...
     SV_offset_CA_code, E_CA_code, L_CA_code, fid, file, fileNo, Nfiles) 
% function SIGNAL_TRACKING(doppler_frequency, code_start_time, in_sig, PRN,...
%      SV_offset_CA_code, E_CA_code, L_CA_code, fid, file, fileNo, Nfiles);
%
% Note that all inputs originate from GPS_SW_RCX.m
% Inputs              Description
% doppler_frequency   Doppler frequency from INITIAL_ACQUISITION
% code_start_time     Code start time from INITIAL_ACQUISITION
% in_sig              Initial 1 second of data passed in from GPS_SW_RCX
% PRN                Current satellite being tracked
% SV_offset_CA_code   satellite offset CA codes
% E_CA_code           satellite offset early CA codes
% L_CA_code           satellite offset late CA codes
% fid                 file pointer to the data
% file                file name pointed to by fid
% fileNo              current file number (or second of data)
% Nfiles              amount of data to be analyzed, in seconds
%
% This calls CA_CORRELATOR, PLLDLL (or FLLDLL), CODE_LOCK_INDICATOR,
% CARRIER_LOCK_INDICATOR, EXTRACT_BIT and performs code and carrier tracking.
% If the DEBUGFLAG flag is set in CONSTANT.m, after each second of data tracked, the program
% will create:
%
% Outputs (saved in .mat files):
% PRN#_hist_#    which is the kth iteration for the PRN and saves all pertinent vectors
%                 (for later analysis if necessary)
% Regardless of the DEBUGFLAG flag, the following file is always created:
% bit_cst_hist_#  which is a continuous file for the bits, code start times, C/No, error bias,
%                 phase error, and code/carrier lock indicators.  
%
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu), Brady O'Hanlon (bwo1@cornell.edu)
% Copyright 2006, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853
constant_h;
loadFile = 0;
h = waitbar(0,sprintf('Tracking PRN %02d, second #%d',PRN,1));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Now initialize variables for parameters and histories       %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create storage vectors here, preinitialize for speed
max_index = floor(length(in_sig)/FSAMP_MSEC);

%the following seven *_hist are perpetual variables that are required to 
%determine the navigation solution.  They are stored as
%bit_cst_hist_PRN.mat in the GPS_SW_RCX.m directory

cst_overall_hist = zeros(Nfiles*1000-1,1); %the code start times
bit_overall_hist = zeros(Nfiles*1000-1,1); %the raw bits
code_lock_overall_hist = zeros(Nfiles*1000-1,1); 
carrier_lock_overall_hist = zeros(Nfiles*1000-1,1);
CNo_overall_hist = zeros(Nfiles*1000-1,1);
phi_overall_hist = zeros(Nfiles*1000-1,1); %the carrier phase
w_df_overall_hist = zeros(Nfiles*1000-1,1); %the doppler shift (radians)
start = 0; %indexing variable for saving in the above vectors

%if you are debugging, create these history vectors to be saved
if(DEBUGFLAG)
    %the phase at the intermediate freq.
    phi_if_hist = zeros(max_index,1);
    %the CA code frequency history
    chip_rate_hist = zeros(max_index,1); 
    %the CA code period history
    tau_hist = zeros(max_index,1); 
    %the I early history
    I_early_hist = zeros(max_index,1);
    %the Q early history
    Q_early_hist = zeros(max_index,1);
    %the I late history
    I_late_hist = zeros(max_index,1);
    %the Q late history
    Q_late_hist = zeros(max_index,1);
    %the I prompt history
    I_prompt_hist = zeros(max_index,1);
    %the Q prompt history
    Q_prompt_hist = zeros(max_index,1);
    %the phase error history
    err_phs_hist = zeros(max_index,1);
    %the code error history
    err_code_hist = zeros(max_index,1);
    %The theta-angle history, used to determine carrier lock
    theta_hist = zeros(max_index,1);
end

%code_start_time --- time to first CA code in file, indexed from beginning
%of file
index = 1;
code_start_time_k = code_start_time;  %this is the initial code start time

%from here, some variables will be NAME_k or NAME_km1 or NAME_kp1
%k = current iteration, km1 = previous iteration, kp1 = next iteration

%grab most recent value of phi
phi_k = 0;  %this is zero initially

%start up the phi value for base-band mixing
phi_if_k = mod((-phi_k + code_start_time_k*W_FC),2*pi);

%and fire up the Doppler Frequencies
%the doppler freq. in natural freq.
w_df_k = doppler_frequency*2*pi; 
% the next iteration has the same doppler freq.
w_df_kp1 = w_df_k;  
% the next iteration doppler frequency rate is zero initially
w_df_dot_kp1 = 0;

%fire up the chipping rates
%this chipping rate is carrier aided by the w_df_k/(2*pi*L1) term which adds in the doppler
chip_rate_k = CA_FREQ*(1 + w_df_k/(2*pi*L1)); 
%since w_df_kp1 = w_df_k, then chip_rate_kp1 will be equal to chip_rate_k;
chip_rate_kp1 = chip_rate_k; 

%fire up tau, which is the CA code period (nominally 1 msec)
tau_k = NUM_CHIPS/chip_rate_k;

%and prepare the next code_start_time, which is the current code_start_time
%plus the current CA code period
code_start_time_kp1 = code_start_time_k + tau_k;

%initialize w_if for base-band mixing
w_if_k = W_FC - w_df_k;

%Now actually do the first correlation to set-up values for iterative
%process
t0 = 0;  %since this is the first run into the data signal and we are at 
%the beginning of a data stream, this is zero (see CA_CORRELATOR.m)

%initialize I, Q early, late, prompt
[I_prompt_kp1, Q_prompt_kp1, I_early_kp1, Q_early_kp1, I_late_kp1, Q_late_kp1] ...
    = ca_correlator(code_start_time_k, in_sig, w_if_k, SV_offset_CA_code, E_CA_code, L_CA_code,...
    phi_if_k, t0);

%update the phase estimate, which is the current phase plus the doppler
%shift times the chipping period (recall that w_df_k = cycles/sec and
%tau_k = sec, so the units work out to be cycles)
phi_kp1 = phi_k + tau_k*w_df_k;  

%update the intermediate phase estimate
phi_if_kp1 = mod((phi_if_k + tau_k*w_if_k),2*pi);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The following lines of code are initialization for the PLL routine and %
% are not used in the FLL/DLL estimates                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%initialize past history error phases
err_phs_k = -atan(Q_prompt_kp1/I_prompt_kp1);
err_phs_km1 = err_phs_k;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

theta_k = eps; %note: eps is 2^-52, the spacing between floating point numbers in matlab
%Aribitrarily set the first bit in the stream to be a 'zero'
bit_k = 0;
%the first CNo_k value is not used, set it to eps (same with I_prompt_k and
%Q_prompt_k
I_prompt_k = eps;
Q_prompt_k = eps;
CNo_k = eps;

%Record t = 0 data into variables
cst_overall_hist(index,1) = code_start_time_k;
w_df_overall_hist(index,1) = w_df_k;
bit_overall_hist(index,1) = bit_k;
code_lock_overall_hist(index,1) = 0;
carrier_lock_overall_hist(index,1) = 0;
CNo_overall_hist(index,1) = CNo_k;   
phi_overall_hist(index,1) = phi_k;
%save the debugging variables, if necessary
if(DEBUGFLAG)   
    phi_if_hist(index,1) = phi_if_k;
    chip_rate_hist(index,1) = chip_rate_k;
    tau_hist(index,1) = tau_k;
    I_early_hist(index,1) = 0;
    Q_early_hist(index,1) = 0;
    I_late_hist(index,1) = 0;
    Q_late_hist(index,1) = 0;
    I_prompt_hist(index,1) = 0;
    Q_prompt_hist(index,1) = 0;
    err_code_hist(index,1) = 0;
    err_phs_hist(index,1) = err_phs_k;
    theta_hist(index,1) = theta_k;
end

%stop is the end time of in_sig (minus a buffer).  It tells us we need to 
%load the next millisecond of data
stop = floor(length(in_sig)-4*FSAMP_MSEC)*TP + t0;

%we now have to iterate over the total number of seconds specified by the 
%user in GPS_SW_RCX.m at line number 82
while(fileNo-1 <= Nfiles)
    if(loadFile)  %if we arrived at the end of the current 1 sec of data
        %load the next second of data
        %update the wait bar
        waitbar((fileNo-1)/Nfiles,h,sprintf('Tracking PRN %02d, second #%d',PRN,fileNo-1));
        loadFile = 0;
        %load the next second of data
        [in_sig, fid, fileNo] = load_gps_data(file,fid,fileNo);
        %augment the data with the left over data from the previous second
        in_sig = [samp_buff; in_sig];
        %and update the stop time
        stop = floor(length(in_sig)-2*FSAMP_MSEC)*TP + t0;

        %re-initialize history vectors for this file
        max_index = floor(length(in_sig)/FSAMP_MSEC);

        %clear past histories (makes matlab run a little bit better)
        if(DEBUGFLAG)
            clear phi_hist phi_if_hist chip_rate_hist tau_hist I_early_hist...
                Q_early_hist I_late_hist Q_late_hist I_prompt_hist Q_prompt_hist...
                err_phs_hist err_code_hist theta_hist;
        end;
              
        if(DEBUGFLAG)           
            phi_if_hist = zeros(max_index,1);
            chip_rate_hist = zeros(max_index,1);
            tau_hist = zeros(max_index,1);
            I_early_hist = zeros(max_index,1);
            Q_early_hist = zeros(max_index,1);
            I_late_hist = zeros(max_index,1);
            Q_late_hist = zeros(max_index,1);
            I_prompt_hist = zeros(max_index,1);
            Q_prompt_hist = zeros(max_index,1);
            err_phs_hist = zeros(max_index,1);
            err_code_hist = zeros(max_index,1);
            theta_hist = zeros(max_index,1);
        end
        %and re-start the index
        start = start+index;
        index = 0;        
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% THIS IS THE MAIN PROCESS OF SIGNAL TRACKING AND PERFORMS THE CODE &  
%%% CARRIER TRACKING OF THE SIGNAL                                       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %loop through until code_start_time >= stop, which indicates that we
    %have arrived at the end of the current file
    while(code_start_time_k<stop)
        if(code_start_time_k<0)     %this is here b/c when you're tracking
            warning('Code start time < 0...aborting');
            break;                  %noise, sometimes the code start time
        end;                        %can go bad
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %We now update all the state variables (kp1->k, k->km1) %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        err_phs_km2 = err_phs_km1;
        
        I_prompt_km1 = I_prompt_k;
        Q_prompt_km1 = Q_prompt_k;
        w_df_km1 = w_df_k;
        err_phs_km1 = err_phs_k;
        bit_km1 = bit_k;
        
        %and update the code_start_time now
        code_start_time_kp1 = code_start_time_k + tau_k;        
        code_start_time_k = code_start_time_kp1;
        chip_rate_k = chip_rate_kp1;
        I_early_k = I_early_kp1;
        Q_early_k = Q_early_kp1;
        I_late_k  = I_late_kp1;
        Q_late_k  = Q_late_kp1;
        I_prompt_k = I_prompt_kp1;
        Q_prompt_k = Q_prompt_kp1;
        w_df_dot_k = w_df_dot_kp1;
        w_df_k = w_df_kp1;        
        phi_k = phi_kp1;
        phi_if_k = phi_if_kp1;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %End update of state variables %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %update the intermediate frequency estimate
        w_if_k = W_FC - w_df_k;

        %determine the current CA code period
        tau_k = 1023/chip_rate_k;
        
        %save previous C/No for use in FLLDLL
        CNo_km1 = CNo_k;
        %now compute CNo for code lock indicator
        CNo_k = (I_prompt_k^2+Q_prompt_k^2);
        %Now check for CODE_LOCK
        if(CNo_k>CNO_MIN_COUNTS)
            code_lock_k=1;
        else
            code_lock_k=0;
        end 

        %now compute carrier lock
        [carrier_lock_k, theta_k] = carrier_lock_indicator(I_prompt_k, Q_prompt_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1);

        %now determine what the bit is for the current iteration
        bit_k = extract_bit(theta_k, bit_km1);

        %run the CA_CORRELATOR to determine the next iteration I,Q E,P,L        
        [I_prompt_kp1, Q_prompt_kp1, I_early_kp1, Q_early_kp1, I_late_kp1, Q_late_kp1] ...
            = ca_correlator(code_start_time_k, in_sig, w_if_k, SV_offset_CA_code, E_CA_code, L_CA_code,...
            phi_if_k, t0);
        
        %Get the next iteration phase estimates
        phi_kp1 = phi_k + tau_k*w_df_k;
        
        phi_if_kp1 = mod((phi_if_k + tau_k*w_if_k),2*pi);

        %Now run either the PLL/DLL or the FLL/DLL filters
        %%If USE_PLL = 1 and the code start time is greater than the
        %%PLL_switch_time, run the PLL
%         if(USE_PLL && (code_start_time_k > PLL_SWITCH_TIME))
%             if(INITIALIZE_PLL)
%                 %these need to be initialized properly for the PLL to lock
%                 %in
%                 INITIALIZE_PLL = 0;
%                 w_df_km1 = w_df_k;
%                 err_phs_km1 = 0;
%                 err_phs_km2 = 0;
%             end
%             %run the PLL/DLL
%             [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1] = plldll(I_prompt_k, Q_prompt_k,...
%                 I_early_k, Q_early_k, I_late_k, Q_late_k, err_phs_km1, err_phs_km2, w_df_k, w_df_km1);
%         else
%             %run the FLL/DLL
% %             [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1, w_df_dot_kp1] = flldll_fixed(I_prompt_k, Q_prompt_k,...
% %                 I_early_k, Q_early_k, I_late_k, Q_late_k, w_df_k, w_df_dot_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1);
%             [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1, w_df_dot_kp1] = flldll(I_prompt_k, Q_prompt_k,...
%                 I_early_k, Q_early_k, I_late_k, Q_late_k, w_df_k, w_df_dot_k, I_prompt_km1, Q_prompt_km1, CNo_k, CNo_km1);
%         end

        %Execute tracking loops. DLL must be run after FLL,
        %as it needs the new w_df value for carrier-aiding.
        if(USE_PLL && (code_start_time_k > PLL_SWITCH_TIME))
            if(INITIALIZE_PLL)
                %these need to be initialized properly for the PLL to lock
                %in
                INITIALIZE_PLL = 0;
                w_df_km1 = w_df_k;
                err_phs_km1 = 0;
                err_phs_km2 = 0;
            end
            %run the PLL/DLL
            [chip_rate_kp1, err_phs_k, err_code_k, w_df_kp1] = plldll(I_prompt_k, Q_prompt_k,...
                I_early_k, Q_early_k, I_late_k, Q_late_k, err_phs_km1, err_phs_km2, w_df_k, w_df_km1);
        else
            %Run the FLL.
            if(USE_FLL_FIXED)
                [w_df_kp1, w_df_dot_kp1, err_phs_k]=fll_fixed(I_prompt_k, Q_prompt_k,...
                                                              w_df_k, w_df_dot_k,...
                                                              I_prompt_km1, Q_prompt_km1,...
                                                              CNo_k, CNo_km1);
            else
                [w_df_kp1, w_df_dot_kp1, err_phs_k]=fll_float(I_prompt_k, Q_prompt_k,...
                                                              w_df_k, w_df_dot_k,...
                                                              I_prompt_km1, Q_prompt_km1,...
                                                              CNo_k, CNo_km1);
            end
        end
        %Run the DLL.
        if(USE_DLL_FIXED)
            [chip_rate_kp1, err_code_k]=dll_fixed(I_early_k,Q_early_k,...
                                                  I_late_k,Q_late_k,...
                                                  w_df_kp1);
        else
            [chip_rate_kp1,err_code_k]=dll_float(I_early_k,Q_early_k,...
                                                 I_late_k,Q_late_k,...
                                                 w_df_kp1);
        end

        % record time k data into history vectors
        index = index+1;
        cst_overall_hist(start+index,1) = code_start_time_k;
        CNo_overall_hist(start+index,1) = CNo_k;
        code_lock_overall_hist(start+index,1) = code_lock_k;
        carrier_lock_overall_hist(start+index,1) = carrier_lock_k;
        bit_overall_hist(start+index,1) = bit_k;        
        w_df_overall_hist(start+index,1) = w_df_k;
        phi_overall_hist(start+index,1) = phi_k;
        
        if(DEBUGFLAG)           
            phi_if_hist(index,1) = phi_if_k;
            chip_rate_hist(index,1) = chip_rate_k;
            tau_hist(index,1) = tau_k;
            I_early_hist(index,1) = I_early_k;
            Q_early_hist(index,1) = Q_early_k;
            I_late_hist(index,1) = I_late_k;
            Q_late_hist(index,1) = Q_late_k;
            I_prompt_hist(index,1) = I_prompt_k;
            Q_prompt_hist(index,1) = Q_prompt_k;
            err_phs_hist(index,1) = err_phs_k;
            err_code_hist(index,1) = err_code_k;
            theta_hist(index,1) = theta_k;
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% THIS IS THE END OF THE MAIN PROCESS OF SIGNAL TRACKING THAT PERFORMS %%
    %% THE CODE & CARRIER TRACKING OF THE SIGNAL                            %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%s%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % now save data if code_start_time_k>stop for next iteration of file
    if(code_start_time_k>stop)

        index_left = floor((code_start_time_kp1-t0)/TP);
        t0 = index_left*TP+t0-TP;

        %grab what's left of data samples from current time and determine
        %current stop time
        samp_buff = in_sig(index_left:length(in_sig));
        loadFile = 1;
    end

    %Delete extra rows from the arrays and save the data for the current
    %sets
    if(DEBUGFLAG)
        t0km1 = t0;
        code_start_time_hist = cst_overall_hist(start+1:start+index,1);
        w_df_hist = w_df_overall_hist(start+1:start+index,1);
        phi_if_hist = phi_if_hist(1:index,1);
        chip_rate_hist = chip_rate_hist(1:index,1);
        tau_hist = tau_hist(1:index,1);
        I_early_hist = I_early_hist(1:index,1);
        Q_early_hist = Q_early_hist(1:index,1);
        I_late_hist = I_late_hist(1:index,1);
        Q_late_hist = Q_late_hist(1:index,1);
        I_prompt_hist = I_prompt_hist(1:index,1);
        Q_prompt_hist = Q_prompt_hist(1:index,1);
        err_phs_hist = err_phs_hist(1:index,1);
        err_code_hist = err_code_hist(1:index,1);
        CNo_hist = CNo_overall_hist(start+1:start+index,1);
        code_lock_hist = code_lock_overall_hist(start+1:start+index,1);
        carrier_lock_hist = carrier_lock_overall_hist(start+1:start+index,1);
        bit_hist = bit_overall_hist(start+1:start+index,1);
        theta_hist = theta_hist(1:index,1);
        file_name = sprintf('PRN%i_hist_%i',PRN,fileNo-1);

        save(file_name,'code_start_time_hist','phi_if_hist','w_df_hist',...
            'chip_rate_hist','tau_hist','I_early_hist','Q_early_hist','I_late_hist',...
            'Q_late_hist','I_prompt_hist','Q_prompt_hist','err_phs_hist','err_code_hist',...
            'CNo_hist','code_lock_hist','carrier_lock_hist',...
            'bit_hist','theta_hist','PRN','t0km1');
    end    
end
%since CNo_k for k=1 is never computed, this makes the data look strange
% unless the first value is skipped.  I am instead arbitrarily setting it
% to the second value to avoid this.
CNo_overall_hist(1) = CNo_overall_hist(2);
%save the data required for the navigation solution
save(sprintf('bit_cst_hist_%i',PRN),'cst_overall_hist','bit_overall_hist',...
    'code_lock_overall_hist','carrier_lock_overall_hist','CNo_overall_hist','w_df_overall_hist', 'phi_overall_hist');
close(h);
