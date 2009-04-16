function PSEUDO_EPHEM(svids, PR_sam_per)
% function PSEUDO_EPHEM(svids, PR_sam_per)
% 
% Inputs          Description
% svids           Array of at least four satellites to generate a nav. soln
% PR_sam_per      Nav. soln interval, in units of 20 msec.
% 
% This program uses the output files generated in TRACKING_LOOPS (bit_cst_hist_#.mat files)
% It loads each of the files as specified in svids, and 'grabs' (GRAB_RAW_BITS) the valid data (usually
% the data is valid from 500 msec - end of the file).
% The program then runs bit/frame locks (BIT_LOCK, FRAME_LOCK)
% to ensure that the data is 'good'.  Once the bit and frame locks have run, the program runs 
% EXTRACT_EPHEM to generate the ephemerides necessary for the navigation solution.  
% Finally the PR / nav. soln. is obtained by running 
% PSEUDORANGE, which calls upon modified ECE415 files to obtain the
% navigation solution 
%
% Note that this function requires globals created in CONSTANT.m
% 
% Outputs         Description
% ephem.asc       Ephemerides as generated from demodulated data
% obs.asc         Pseudorange measurements at specified sampling period
%
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu)
% Copyright 2006, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853
% bwo1: modified 1/4/08

%load the bit_cst_hist for initialization
load(sprintf('bit_cst_hist_%i',svids(1)));
dim1 = length(cst_overall_hist)-20;
dim2 = length(svids);
%create empty vectors for speed
raw_bits = zeros(dim1,dim2);
cst = zeros(dim1,dim2);
clh = zeros(dim1,dim2);
doppler = zeros(dim1,dim2);

%grab the bits for the first svid in the array svids
raw_bits(1:dim1,1) = bit_overall_hist(1:dim1);
cst(1:dim1,1) = cst_overall_hist(1:dim1);
clh(1:dim1,1) = carrier_lock_overall_hist(1:dim1);
doppler(1:dim1,1) = w_df_overall_hist(1:dim1)/(2*pi);
%now load the rest of the files and grab the bits, cst, and carrier_lock
%histories.
for x=2:dim2
    load(sprintf('bit_cst_hist_%i.mat',svids(x)));
    raw_bits(1:dim1,x) = bit_overall_hist(1:dim1);
    cst(1:dim1,x) = cst_overall_hist(1:dim1);
    clh(1:dim1,x) = carrier_lock_overall_hist(1:dim1);
    doppler(1:dim1,x) = w_df_overall_hist(1:dim1)/(2*pi);
end

%now get bit lock and downsample the bit stream on the 1st SV
[bit, lock, ind] = BIT_LOCK(raw_bits(:,1));

%all satellites will have the same number of bits, preinitialize vectors
bits = zeros(length(bit),length(svids));
bit_index = bits;
bit_lock = zeros(1,length(svids));

%save SV 1 data
bits(:,1) = bit;
bit_index(:,1) = ind;
bit_lock(:,1) = lock;

%now do bit lock on the other y-1 satellites
for y=2:length(svids)
    [bits(:,y), bit_lock(:,y), bit_index(:,y)] = BIT_LOCK(raw_bits(:,y));
end;

if(sum(bit_lock) ~= length(svids))
    y = find(bit_lock==0);
    fprintf('Bit lock failed on SVs '), fprintf('%d ', svids(y));
%    error('Unable to process data');
    display('ignoring...');
end

%now get frame lock
sfindex = zeros(1,length(svids));
data = zeros(length(bits),length(svids));
frame_lock = zeros(1,length(svids));

%and now obtain frame lock on each of the y satellites
for y=1:length(svids)
    [sfindex(1,y) data(:,y) frame_lock(1,y)] = FRAME_LOCK(bits(:,y));
end;

if(sum(frame_lock)~=length(svids))
    y = find(frame_lock==0);
    fprintf('Frame lock failed on SVs '), fprintf('%d ', svids(y));
    error('Unable to process data.');
end

%now extract the ephemerides and save them
GPS_time = zeros(length(svids),1);
ephem = zeros(length(svids),24);
for y=1:length(svids)
     [ephem(y,:) GPS_time(y,:)] = extract_ephem(data(:,y), sfindex(1,y), svids(y));
end

%and now save the ephemerides.
save ephem.asc ephem -ascii -double

%finally now determine the PR's at a sample rate as specified by the passed
%in parameter
[PR,time,posHIST] = PR_POS_TIME(GPS_time(1,:), cst, sfindex, svids, bit_index, PR_sam_per);

%now create obs.asc file

%create a line vector to match the first column of ece415 format
lines = (1:length(PR(:,1)))';

obs = zeros(length(lines),2+2*length(svids));
%now cat lines with time
obs(:,1:2) = [lines time];

%now add SVnum's and PR's associated with SV and also doppler
for x=1:length(svids)
    obs(:,2*x+1:2*x+2) = [svids(x)*ones(length(lines),1) PR(:,x)];
end

%save the file as obs.asc, and the posHIST of the navigation solutions
save 'obs.asc' 'obs' -ascii -double
save('posHIST.mat','posHIST')
return