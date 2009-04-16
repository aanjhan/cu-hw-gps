function [ephem, GPS_time] = EXTRACT_EPHEM(data, sfindex, SV)
% function [ephem, GPS_time] = EXTRACT_EPHEM(data, sfindex, SV) 
%
% Inputs        Description
% data          Down sampled data as obtained from bit and frame locks
% sfindex       Index of the first bit of the sfidnum
% SV            satellite vehicle number
% 
% Pseudo-ephem steps through each subframe and extracts the various bit
% fields required for navigation.  The bit fields are specified in the GPS
% ICD.  
%
% Outputs        Description
% ephem          The ephemerides of subframes 1-3 as extracted
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu) and Bryan Galusha (btg3@cornell.edu) and Jeanette Lukito
% (jl259@cornell.edu)
% Copyright 2006, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853


% Initialization
TOW=0;            %pos 3
week_num=0;       %pos 2
T_GD=0 ;          %pos 23
t_oc=0;           %pos 24
af2=0;            %pos 19
af1=0;            %pos 20
af0=0;            %pos 21

C_rs=0;           %pos 17
delt_n=0;         %pos 11
M_o=0;            %pos 8
C_uc=0;           %pos 14
e_s=0;            %pos 5
C_us=0;           %pos 15
sq_as=0;          %pos 6
t_oe=0;           %pos 4

C_ic=0;           %pos 18
omega_e=0;        %pos 9
C_is=0;           %pos 19
i_0=0;            %pos 12
C_rc=0;           %pos 16
w=0;              %pos 7
omega_dot=0;      %pos 10
idot=0;           %pos 13

%the following if block checks to be sure we have enough data before the
%current subframe for parity (ie we need bits D30 and D29 of the previous
%word to check for parity)

if(mod(sfindex,100)<3)
    sfindex = sfindex+300;
end

%have to do this here for correct data inversion
%do parity check of first subframe available
[data1, flag] = parity_check(data(sfindex:sfindex+300-1),data(sfindex-2),data(sfindex-1));
%determine the subframe ID of this data
sfidnum = mat2int(data1(50:52));

if(flag)
    error('PARITY CHECK ERROR in subframe %d data', SV);
end

%find index of subframe 1 if sfidnum !=1
if sfidnum~=1
    sf1_idx =(6-sfidnum)*300 + sfindex;
    %offset below corrects GPS time for first SF observed
    offset = (6-sfidnum)*6;
    %parity check subframe 1
    [data1, flag] = parity_check(data(sf1_idx:sf1_idx+300-1),data(sf1_idx-2),data(sf1_idx-1));
else %otherwise we have subframe 1 as the first subframe  
    sf1_idx = sfindex;
    offset = 0;
end

if(flag)
    error('PARITY CHECK ERROR in subframe %d data', SV);
end

%the GPS_time associated with the current subframe is obtained by looking
%at the z-count in the current subframe and subtracting 6 seconds.  This is
%because the z-count refers to the time of transmission of the _first_ bit
%of the next subframe.  Also don't forget to subtract off 'offset'.
GPS_time = mat2int(data1(31:47))*4*1.5-offset-6;

% retrieve the relevant ephemerides
week_num = mat2int(data1(61:70))+1024;
TOW = GPS_time+week_num*86400*7;  %this is the formal definition of TOW,
%the value reported here will differ from the CORS reported value because 
%TOW is dependent on the observation time of the ephemerides, which
%differs from receiver to receiver.  All other parameters should match to
%an accuracy of ~10^-15 when taking the difference
T_GD = twoscomp2dec(data1(197:197+7))*2^-31; 
t_oc = mat2int(data1(219:219+15))*2^4;
af2 = twoscomp2dec(data1(241:241+7))*2^-55;
af1 = twoscomp2dec(data1(249:249+15))*2^-43;
af0 = twoscomp2dec(data1(271:271+21))*2^-31;

%calculate start of subframe 2
sf2_idx = sf1_idx+300;

%parity check subframe 2 data
[data2, flag] = parity_check(data(sf2_idx:sf2_idx+300-1),data(sf2_idx-2),data(sf2_idx-1));
if(flag)
    error('PARITY CHECK ERROR in subframe %d data', SV);
end
%and retrieve the relevant ephemerides
C_rs = twoscomp2dec(data2(69:69+15))*2^-5;
delt_n = twoscomp2dec(data2(91:91+15))*pi*2^-43;
M_o = twoscomp2dec([data2(107:107+7) data2(121:121+23)])*pi*2^-31;
C_uc = twoscomp2dec(data2(151:151+15))*2^-29;
e_s = mat2int([data2(167:167+7) data2(181:181+23)])*2^-33;
C_us = twoscomp2dec(data2(211:211+15))*2^-29;
sq_as = mat2int([data2(227:227+7) data2(241:241+23)])*2^-19;
t_oe = mat2int(data2(271:271+15))*2^4;

%calculate start of subframe 3
sf3_idx = sf2_idx+300;

%perform parity check
[data3, flag] = parity_check(data(sf3_idx:sf3_idx+300-1),data(sf3_idx-2),data(sf3_idx-1));
if(flag)
    error('PARITY CHECK ERROR in subframe %d data', SV);
end
%and retrieve the ephemerides
C_ic = twoscomp2dec(data3(61:61+15))*2^-29;
omega_e = twoscomp2dec([data3(77:77+7) data3(91:91+23)])*pi*2^-31;
C_is = twoscomp2dec(data3(121:121+15))*2^-29;
i_0 = twoscomp2dec([data3(137:137+7) data3(151:151+23)])*pi*2^-31;
C_rc = twoscomp2dec(data3(181:181+15))*2^-5;
w = twoscomp2dec([data3(197:197+7) data3(211:211+23)])*pi*2^-31;
omega_dot = twoscomp2dec(data3(241:241+23))*pi*2^-43;
idot = twoscomp2dec(data3(279:279+13))*pi*2^-43;

%now write the vector in the appropriate order for ephem.asc
ephem=[SV week_num TOW t_oe e_s sq_as w M_o omega_e omega_dot delt_n i_0 idot C_uc C_us C_rc C_rs C_ic C_is af0 af1 af2 T_GD t_oc];

return;