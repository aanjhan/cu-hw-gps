function [in_sig, fid, fileNo] = load_gps_data(file, fid, fileNo)
% function [in_sig, fid, fileNo] = LOAD_GPS_DATA(file, fid, fileNo)
%
% INPUTS
% file      GPS data file, either a *.bin or a parsed *.mat
% fid       The file pointer
% fileNo    The current file number
%
% This function loads either *.bin GPS data _or_ *.mat GPS data.  The
% suffix on the file MUST be *.mat or *.bin
% This function requires convertbitpack2bit1.c, which may be compiled by
% calling mex convertbitpack2bit1.c (mex -setup may be req'd first)
%
% OUTPUTS
% in_sig    1 second of +/-1's and +/-3's data
% fid       the file pointer
% fileNo    the next file in the sequence of files
%
% AUTHORS:  Alex Cerruti (apc20@cornell.edu)
% Copyright 2006, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853


type = file(end-2:end);
%check to be sure that the file extension is valid
while(~(strcmpi(type,'dat')||strcmpi(type,'mat')||(strcmpi(type,'bin'))))
    file = input('File not found, enter the file name: ','s');
    type = file(end-2:end);
end
%if we have a .dat or .bin file
if(strcmpi(type,'dat')||strcmpi(type,'bin'))
    if(fileNo == 1)
        fid = fopen(file,'rb');
        while(fid<0)
            fprintf('\nFile not found')
            file = input('Enter the digitized data file name: ','s');
            fid = fopen(file,'rb');
        end
    end
    
    % read in data from a a file
    N=357143;  % 1 second worth of 32-bit unsigned integers
    x=fread(fid,N,'*uint32');
    % convert this binary data into +-1, +-3 format
    in_sig=zeros(16*N,1);
    in_sig=convertbitpack2bit1(x);
%if we have multiple mat files
elseif(strcmpi(type,'mat'))
%     if(fileNo == 1)
%         %obtain the file name
%         if(length(file) == 12)
%             fileNo = eval(file(end-5:end-4));
%         else
%             fileNo = eval(file(end-4));
%         end
%     end
    if(fileNo>1)
        file = sprintf('%s%d.mat',file(1:end-5),fileNo);
    end
    %load the file
    load(file);
    fid = -1;
    if(length(file) == 12)
        fileNo = eval(file(end-5:end-4));
    else
        fileNo = eval(file(end-4));
    end
end
fileNo = fileNo+1;
return;