function  [bit, lock, index] = BIT_LOCK(data)
%function  [bit, lock, index] = BIT_LOCK(data)
%
% This function will take as input:
%
% Input               Description
% data                an arbitrary length of unsynchronized data (1s & 0s)
% 
% The function will then perform a histogram analysis on the data using a
% 20 bin window.  When the average bit transition time is found (the bin
% number of the peak of the histogram) we then use that information to
% create an optimal time at which to sample the value of the bits.  The
% resulting bit stream (bit) is downsampled and bit synchronized.  A bit
% lock indicator is also provided (you must uncomment line 53 to use this 
% feature).
% 
% The outputs are:
% 
% Output              Description
% bit                 the bit synchronized data stream
% lock                a bit lock indicator (0 for no lock, 1 for lock)
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), Mike Muccio
%(mtm15@cornell.edu)
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853

%declare global constants
CONSTANT_H;

%initialize histogram bins and indicator
bin = zeros(1,20);
lock = 0;

%perform histogram analysis with windows of 20 points
for i=1:20:length(data)-20
    
    window = data(i:1:i+20);
    
    %check bins for transitions
    for j=2:1:21
        if(window(j)~=window(j-1))
            if(j==21)
                bin(1)=bin(1)+1;
            else
                bin(j)=bin(j)+1;
            end
        end
    end
end

%stem plot histogram and get max bin
%stem(bin);
[maxval maxbin] = max(bin);

%calculate indicator threshold
%Note that NBS is a statistical value of the # of 
%transitions/second and can be modified in CONSTANT.m
NBS1 = NBS*(length(data)/1000);

%set indicator
if(maxval>NBS1)
    lock = 1;
end

%downsample bit stream
index = (maxbin:20:length(data))';
bit = data(index);
return