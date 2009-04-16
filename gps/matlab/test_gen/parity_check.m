function [data, flag] = parity_check(data_in,D29,D30)
%function [data, flag] = PARITY_CHECK(data_in,D29,D30)
%
%INPUTS
%data_in = the input data, one subframe (300 bits) at a time
%D29     = the D(29) parity bit from the PREVIOUS word
%D30     = the D(30) parity bit from the PREVIOUS word
%
%OUTPUTS
%data    = the output data, corrected
%flag    = 0 if no errors detected, 1 otherwise
%
% This function does the parity check on the received downsampled bits
% and decodes them properly (i.e., inverts as necessary).  
% This function will run inside of EXTRACT_EPHEM and checks
% the data parity for each subframe.  If the data is correct, flag = 1.
% See GPS ICD Rev. C last five pages for the algorithm implemented below.
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu)
%           Brady O'Hanlon (bwo1@cornell.edu)
% Copyright 2008, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853

%preinitialize the data output vector for speed
data = NaN(1,300);
%set an error flag
flag = 0;
%step through the indices in steps of 30 = 1 word
for ind=1:30:271
    %get the current data word
    data_word = data_in(ind:ind+29);
    %if bit D30 = 1, invert portion of data_word
    if(D30 == 1)
        data_word(1:24) = ~data_word(1:24);
    end
    D = NaN(1,30);
    %parity check the rest of the word
    %note that modulo 2 addition is equivalent to xor
    D(25) = mod(D29+sum(data_word([1 2 3 5 6 10 11 12 13 14 17 18 20 23])),2);
    D(26) = mod(D30+sum(data_word([2 3 4 6 7 11 12 13 14 15 18 19 21 24])),2);
    D(27) = mod(D29+sum(data_word([1 3 4 5 7 8 12 13 14 15 16 19 20 22])),2);
    D(28) = mod(D30+sum(data_word([2 4 5 6 8 9 13 14 15 16 17 20 21 23])),2);
    D(29) = mod(D30+sum(data_word([1 3 5 6 7 9 10 14 15 16 17 18 21 22 24])),2);
    D(30) = mod(D29+sum(data_word([3 5 6 8 9 10 11 13 15 19 22 23 24])),2);
    %does the parity check pass? compare the extracted D to the original
    %data_word
    if(D(25:30)==data_word(25:30))
        %the output data is data_word
        data(ind:ind+29) = data_word;
        %store D29 and D30 to check parity on the next word
        D29 = D(29);
        D30 = D(30);
    else
        %it didn't pass, throw an error
        flag = 1;
        return;
    end
end
return;