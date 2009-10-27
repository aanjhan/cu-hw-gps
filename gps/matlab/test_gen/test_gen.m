%test_gen - Generate simulated SV signal.
%
%Inputs:
%  PRN - SV PRN number.
%  length - Signal length [C/A codes].
%  doppler - Doppler shift [Hz].

% SEQUENCE FOR MAKING .vwf FILES:
% - Run test_gen(<any PRN #>,0)
% - Run twos_to_ones(<data>,3)
% - Run write_vwf

function [signal,carrier,code,t]=test_gen(PRN,length,doppler)
    constant_h;
    constant_rcx;
    
    %Signal length in C/A codes.
    range=1:length*FSAMP_MSEC;
    t=0:1/FS:length*T-1/FS;
    t=t(range);
    
    %Generate SV signal with specified PRN and Doppler.
%     if(isnumeric(PRN))
        caCode=cacodegn(PRN);
        code=digitize_ca_prompt(caCode,length);
        code=code*2-1;
        code=code(range);

        f_carrier=FC+doppler;
        carrier=round(cos(2*pi*f_carrier*t)'*3);

        signal=code.*carrier;
%     else
%         code=0;
%         carrier=0;
%         signal=load_gps_data(PRN,0,1);
%         signal=signal(range);
%     end
    
    packed_signal=gps_pack(signal);
%     ones_signal=twos_to_ones(signal,3);

    filename=sprintf('prn%d_%dms_%dHz.dat',PRN,length*T*1000,doppler);
    
    file=fopen(filename,'wb');
    if(file<0)
        disp(sprintf('Unable to open file %s.',filename));
        return;
    end
    fwrite(file,packed_signal);
    fclose(file);
    
%     write_vwf(ones_signal,'channel',filename);
end