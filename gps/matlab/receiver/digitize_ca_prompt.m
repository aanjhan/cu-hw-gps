 function [ca_code_prompt] = DIGITIZE_CA(cacode,length)
% function  [ca_code_prompt] = DIGITIZE_CA(cacode)
%
% This function will take as input:
%
% Input               Description
% t0                  the delay (positive or negative) to start digitization
%                     t0 not used in this script, will be used later in
%                     general case
% cacode              the generated SV_offset_CA_Code from cacodegn to be resampled
% length              the code length in msec
% 
% This function requires globals from CONSTANT.m
%
% The function will then upsampe the CA code from NUM_CHIPS to ONE_MSEC_SAM bits as specified in 
% CONSTANT.m with the given sampling offset as specified by t0 from time t = 0.
% 
% The outputs are:
% Output              Description
% ca_code_prompt      The ca_code at the prompt interval
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), adapted from Mark Psiaki's
%(mlp4@cornell.edu) codeths6.m
%Copyright 2002, Cornell University, Electrical and Computer Engineering, Ithaca, NY 14850
if(nargin==1) length=1; end

constant_rcx;

samp_index = [1:floor(length*ONE_MSEC_SAM)]';               %Generate a sampling vector
%Generate the time base for sampling from the sampling vector
time_base = samp_index*TP;              

%normalize time_base to range from 0 to 1;
time_base_prompt = time_base/0.001;                

%create prompt_sample_times which is scaled from 0 to NUM_CHIPS 
prompt_sample_times =  time_base_prompt*NUM_CHIPS;
% Note if t0.ne.0, then must wrap around which is done in the following
% statment
% prompt_sample_times =  NUM_CHIPS*(time_base_prompt-floor(time_base_prompt));

% finally convert to integers for array access
prompt_sample_index = floor(prompt_sample_times)+1;

% and up-sample the CACODE
ca_code_prompt = cacode(mod(prompt_sample_index-1,NUM_CHIPS)+1); %now 'upsample' for the prompt ca code

return;