function int = mat2int(mat)
% function int = MAT2INT(mat)
% 
% Inputs        Description
% mat           A binary number to be converted into decimal
% 
% MAT2INT simply converts a binary number into decimal
% 
% Outputs       Description
% int           A decimal representation of the input binary number
%
% AUTHORS:  Bryan Galusha (btg3@cornell.edu) and Jeanette Lukito
% (jl259@cornell.edu)
% Copyright 2006, Cornell University, Electrical and Computer Engineering,
% Ithaca, NY 14853

int=0;
mat_len = length(mat);
%Convert to binary
for i=1:mat_len
    if mat(mat_len-i+1)==1;
        int=int+2^(i-1);
    end
end

return;
