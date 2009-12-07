function decimal = twoscomp2dec(binary)
% function decimal = TWOSCOMP2DEC(binary)
% 
% Inputs        Description
% binary        A binary number to be converted into decimal
% 
% TWOSCOMP2DEC simply converts a binary number into decimal using two's
% complement method
% 
% Outputs       Description
% decimal       A decimal representation of the input binary number
%
% AUTHOR:  Brady O'Hanlon
% Copyright 2008, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853

if binary(1) == 0
    decimal = mat2int(binary); 
else
    decimal = -(mat2int(~binary)+1);
end

return;
