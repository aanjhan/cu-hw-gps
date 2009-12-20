%SV Log Generator
%  [signal,t,carrier,code]=log_gen(PRN,sig_length,doppler,save)
%
%  Generate simulated SV signal.
%
%  Inputs:
%    PRN - SV PRN number.
%    sig_length - Signal length [C/A codes].
%    doppler - Doppler shift [Hz].
%      --For scalar values Doppler is held constant.
%      --For vector values Doppler is ramped between the first and second.
%    code_start - Code start [upsampled chips].
%    save - Save log to a file: 0=no, 1=yes.
%
%  Outputs:
%    signal - One's complement SV signal.
%    t - Signal time vector.
%    carrier - Carrier signal.
%    code - Pseudorandom code sequence.

% SEQUENCE FOR MAKING .vwf FILES:
% - Run log_gen(<any PRN #>,<length>,<doppler>,0)
% - Run twos_to_ones(<data>,3)
% - Run write_vwf(<data>,<Verilog subdirectory>,<filename>)

function [signal,t,carrier,code]=log_gen(PRN,sig_length,doppler,code_start,save)
    constant_h;
    constant_rcx;
    
    if(nargin<4)
        code_start=0;
    end
    
    if(nargin<5)
        save=0;
    end
    
    %Specify signal time range.
    t=(0:1/FS:sig_length*T-1/FS)';
    
    %Generate PRN code.
    caCode=cacodegn(PRN);
    code_start=floor(code_start);
    code=digitize_ca_prompt(caCode,sig_length+code_start/ONE_MSEC_SAM);
    code=code(code_start+1:end);
    code=code*2-1;
    
    %Generate carrier.
    if(length(doppler)==2)
        f_carrier=FC+MIXING_SIGN*linspace(doppler(1),doppler(2),length(t))';
    elseif(length(doppler)==1)
        f_carrier=FC+MIXING_SIGN*doppler;
    else
        error('Invalid Doppler shift vector.');
    end
    carrier=round(cos(2*pi*f_carrier.*t)*3);
    
    %Generate signal.
    signal=code.*carrier;
    
    %Save file.
    if(save)
        time=sig_length*T*1000;
        strTime=sprintf('%sms',string_format(time,1));
        if(length(doppler)==2)
            strDoppler=sprintf('%s-%sHz',string_format(doppler(1),1),string_format(doppler(2),1));
        else
            strDoppler=sprintf('%sHz',string_format(doppler,1));
        end
        strCode=sprintf('chip_%d',code_start);
        filename=sprintf('prn%d_%s_%s_%s.dat',PRN,strTime,strDoppler,strCode);
        
        log_write(signal,filename);
        fprintf('Log saved to ''%s''.\n',filename);
    end
    
%     write_vwf(ones_signal,'channel',filename);
end