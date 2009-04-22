function [PR,dopp,time,posHIST] = pr_pos_time(GPS_time, cst_hist, doppler, sfindex, svids, index, PR_sam_per)
% function [PR,time] = PR_POS_TIME(GPS_time, cst_hist, sfindex, svids, index, PR_sam_per)
%
% Inputs          Description
% GPS_time        GPS_time as extracted from the arrival of the first sub-frame
% cst_hist        Code-start-time histories for phase measurements of CA code
% sfindex         Array of indices where the index of the first subframe occurs (from FRAME_LOCK)
% svids           Vector of satellites being tracked
% index           Indices where code-start-times of each bit occur
% PR_samp_per     Pseudorange sampling period
%
% PSEUDORANGE calculates the Pseudorange to each of the satellites.  It does so by first obtaining the
% index of the beginning of the first subframe to arrive in the data.  On the first iteration, the first satellite is assumed
% to have a PR of an integer number of code periods from the receiver (plus transit time of 75 msec).  Each subsequent PR to each SV in
% the array svids can the be calculated as the difference in arrival time of the same bit from the first satellite in the array
% to the current satellite. This is then converted to meters using
% the accepted speed of light from the GPS IS (299792458 m/sec).  The
% program then calls SOLVEPOS_OD to determine the overdetermined
% navigation solution. The GPS_time and internal rcx_time clock is updated to obtain the point when the next PR is measured,
% and the delr's are added in to correct the PR measurement for the next iteration.
%
% Outputs         Description
% PR              Vector of Pseudo-range measurements to be saved into obs.asc
% time            Vector of times (corrected) for obs.asc
% posHIST         nx5 vector of position solutions (time, x ecef, y ecef, z ecef, cdelr)
%
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu)
% Copyright 2007, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14850

%create the PR and posHIST vector for speed
PR = zeros(ceil((length(index)-sfindex(1,1)-1)/(PR_sam_per)-2),length(svids));
dopp = zeros(ceil((length(index)-sfindex(1,1)-1)/(PR_sam_per)-2),length(svids));
posHIST = zeros(ceil((length(index)-sfindex(1,1)-1)/(PR_sam_per)-2),5);
%create a time vector for speed
time = zeros(round((length(index)-sfindex(1,1)-1)/(PR_sam_per))-2,1);
%create the obs vector to be passed into navsoln
obs = zeros(1,2+2*length(svids));

%initialize time variables

% retrieve ephemeris data from input file -- ephem.asc
load ephem.asc;
%to use ION CORRECTION ionCorr_on = 1, no ion corrections ionCorr_on = 0
ionCorr_on = 0;

if(ionCorr_on)
% % load ionospheric correction data
 	load ion.asc;
    ionParam = ion;
    clear ion;
else
    fprintf('ION CORRECTIONS ARE OFF\n');
    ionParam = 0;
end

%This is the receiver clock offset;we have no prior knowledge of it, 
%and can set to 0.  However, for compatibility with 415 code, need non-zero 
%pseudorange at first iteration, so this nheeds to be !=0
current_delr = .06;  

%this is correction to receiver clock offset at each iteration, initially 0
del_delr = 0;

%Time step between solutions; initially set to 0
delT = 0;           

%the initial receiver time is the time of the first subframe for the first 
%satellite at first bit of the first subframe preamble
rcx_time = GPS_time; 

%initial guess (it doesn't really matter what this is)
guess = [42.4 -76.8 220];
guess = ecef(guess);

%iterate through and calculate the PR's to each satellite
for sample=1:length(PR)
    %update the rcx_time by adding in delT and del_delr
    rcx_time = rcx_time + delT + del_delr;
    
    % add the current GPS_time to the obs array for initialization
    % the obs array is the same format as the obs array in the ECE415 code
    % that is obs = [sample GPS_time SV1 PR(SV1) SV2 PR(SV2) ...]
    obs(1:2) = [1 rcx_time];

    %%this for loop actually calculates the pseudoranges
    for x=1:length(svids)
        %obtain the relative pseudorange by comparing the first satellite
        %to the xth satellite's arrival times of the same bit
        Rel_PR = (cst_hist(index(sfindex(x),x),x)-cst_hist(index(sfindex(1),1),1));
        %calculate the true PR = c*(Rel_PR+current_delr)
        PR(sample,x) = 299792458*(Rel_PR+current_delr);
        dopp(sample,x) = doppler(index(sfindex(x),x),x);
        %and write the current PR to the obs array by concatenating 1
        %satellite and 1 pseudorange
        obs(2*x+1:2*x+2) = [svids(x) PR(sample,x)];
    end

    numSats = length(svids);

    % call pseudoCaion passing 'ephem' and 'pseudo' which contains the
    % raw pseudo-ranges and satellite clock corrections
    pseudo_range = pseudocaion(ephem,obs(2:end),ionParam,guess,ionCorr_on);

    % determine pseudo-range measurements 'pseudoR' and GPS time
    % 'gpsTime' of the sample chosen
    pseudoR = zeros(numSats,1);
    for i = 1:numSats
        pseudoR(i) = pseudo_range(2*i+1);
    end

    % call solvePosOD passing pseudo-ranges 'pseudoR', an initial
    % positional guess 'guess', a GPS time 'rcx_time', and ephemeris
    % data 'ephem'
    posOBS = solveposod(ephem,pseudoR,guess,rcx_time);

    % output the navigation solution
    printnav(posOBS);

    %store the current navigation solution
    posHIST(sample,:) = posOBS;

    %record the time that the PR measurement was taken
    time(sample,1) = rcx_time;
    
    bit0 = sfindex(1); %the sfindex of the previous iteration
    %update the sfindex for the _next_ PR measurement
    sfindex = sfindex + PR_sam_per*ones(1,length(svids));
    %update guess - this occasionally makes a difference
    guess = posOBS(2:4);
    %Obtain the current rcx clock offset correction
    del_delr = posOBS(5);
    %correct the receiver clock offset by the above
    current_delr = current_delr+del_delr;

    %and calculate delT, which is added in to rcx_time and GPS_time to
    %update our estimates of the clock
    delT = cst_hist(index(sfindex(1),1),1) - cst_hist(index(bit0,1),1); 
end
return;
