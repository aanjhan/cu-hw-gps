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

function [signal,t,carrier,code]=log_gen(PRN,sig_length,doppler,save)
    constant_h;
    constant_rcx;
    
    if(nargin<4)
        save=0;
    end
    
    %Specify signal time range.
    t=0:1/FS:sig_length*T-1/FS;
    
    %Generate PRN code.
    caCode=cacodegn(PRN);
    code=digitize_ca_prompt(caCode,sig_length);
    code=code*2-1;
    
    %Generate carrier.
    if(length(doppler)==2)
        f_carrier=FC+linspace(doppler(1),doppler(2),length(t));
    elseif(length(doppler)==1)
        f_carrier=FC+doppler;
    else
        error('Invalid Doppler shift vector.');
    end
    carrier=round(cos(2*pi*f_carrier.*t)'*3);
    
    %Generate signal.
    signal=code.*carrier;
    

    %Save file.
    if(save)
        time=sig_length*T*1000;
        if(round(time)==time)
            strTime=sprintf('%dms',time);
        else
            strTime=sprintf('%0.2fms',time);
        end
        if(length(doppler)==2)
            strDoppler=sprintf('%d-%dHz',doppler(1),doppler(2));
        else
            strDoppler=sprintf('%dHz',doppler);
        end
        filename=sprintf('prn%d_%s_%s.dat',PRN,strTime,strDoppler);
        
        file=fopen(filename,'wb');
        if(file<0)
            error('Unable to open file %s.',filename);
        end
        fwrite(file,gps_pack(signal));
        fclose(file);
    end
    
%     write_vwf(ones_signal,'channel',filename);
end