function [ca_code_prompt, ca_code_early, ca_code_late] = digitize_ca(t0,cacode)
% function  [ca_code_prompt, ca_code_early, ca_code_late] = DIGITIZE_CA(t0,cacode)
%
% This function will take as input:
%
% Input               Description
% t0                  the delay (positive or negative) to start digitization
% cacode              the generated SV_offset_CA_Code from cacodegn to be resampled
% 
% The function will then upsampe the CA code from NUM_CHIPS to ONE_MSEC_SAM bits as specified in 
% CONSTANT.m with the given sampling offset as specified by t0 from time t = 0.
% 
% The outputs are:
% Output              Description
% ca_code_prompt      The ca_code at the prompt interval
% ca_code_early       The ca_code CHIPS_EML/2 early
% ca_code_late        The ca_code CHIPS_EML/2 late
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), adapted from Mark Psiaki's
%(mlp4@cornell.edu) codeths6.m
%Copyright 2006, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853

constant_rcx;

%Generate a sampling vector
samp_index = [1:ONE_MSEC_SAM]';               

%Generate the time base for sampling from the sampling vector with the
%appropriate t0 offset
time_base = samp_index*TP+t0;

%constant used to hold a CHIPS_EML/2 value in seconds
half_delt_eml = CHIPS_EML/2*CHIP;

%now shift time_base +/- half_delt_eml for early and late codes
%Shift time for half_delt_eml early
time_quarter_early = time_base+half_delt_eml;
%Shift time half_delt_eml late
time_quarter_late  = time_base-half_delt_eml;

%normalize time_bases to range from 0 to 1;
%Scale time_quarter_early from 0 to 1
time_base_early = time_quarter_early./0.001;
%Scale time_quarter_late from 0 to 1
time_base_late  = time_quarter_late./0.001;
%Scale time_base from 0 to 1
time_base_prompt = time_base./0.001;

%create prompt_sample_times which is scaled from 0 to NUM_CHIPS including
%wrap-around
early_sample_times = time_base_early*NUM_CHIPS;
late_sample_times  = time_base_late*NUM_CHIPS;
prompt_sample_times = time_base_prompt*NUM_CHIPS;

% finally convert to integers for array access
early_sample_index = mod(floor(early_sample_times),1023)+1;
late_sample_index  = mod(floor(late_sample_times),1023)+1;
prompt_sample_index = mod(floor(prompt_sample_times),1023)+1;

% and up-sample the CACODE
ca_code_early = cacode(early_sample_index,1);  
ca_code_late  = cacode(late_sample_index,1);
ca_code_prompt = cacode(prompt_sample_index,1);

return;