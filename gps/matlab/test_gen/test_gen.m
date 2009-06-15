function [signal,carrier,code,t]=test_gen(PRN,pack,filename,send)
    constant_h;
    constant_rcx;
    
    %Signal length in C/A codes.
    acc_length=1;
    range=1:acc_length*FSAMP_MSEC;
    %     range=1:4000;
    t=0:1/FS:acc_length*T-1/FS;
    t=t(range);
    
    if(isnumeric(PRN))
        caCode=cacodegn(PRN);
        code=digitize_ca_prompt(caCode,acc_length);
        code=code*2-1;
        code=code(range);

        doppler=200;
        f_carrier=FC+doppler;
        carrier=round(cos(2*pi*f_carrier*t)'*3);

        signal=code.*carrier;
    else
        code=0;
        carrier=0;
        signal=load_gps_data(PRN,0,1);
        signal=signal(range);
    end
    
    packedSignal=gps_pack(signal);
    ones_signal=twos_to_ones(signal,3);
    
    if(pack)
        frame=[hex2dec('FE');
            hex2dec('ED');
            1;
            floor(size(packedSignal,1)/2^8);
            mod(size(packedSignal,1),2^8);
            packedSignal];
    else
        frame=[hex2dec('FE');
            hex2dec('ED');
            2;
            floor(size(ones_signal,1)/2^8);
            mod(size(ones_signal,1),2^8);
            ones_signal];
    end

    if(nargin<3 || isempty(filename))
        return;
    elseif(~isnumeric(PRN))
        filename=sprintf('_%s',filename);
    end
    
    if(isnumeric(PRN))
        filename=sprintf('prn%d%s',PRN,filename);
    end
    
    file=fopen(sprintf('%s.dat',filename),'wb');
    if(file<0)
        disp(sprintf('Unable to open file %s.',filename));
        return;
    end
    fwrite(file,frame);
    fclose(file);
    
    write_vwf(ones_signal,'channel',filename);
    
    if(nargin>3 && send)
        if(strcmp(computer,'PCWIN'))
            bar=waitbar(0,sprintf('Transfer progress: %dB remaining.',size(frame,1)));
            s=serial('COM4','BaudRate',115200);
            fopen(s);
            for i=1:size(frame,1)
                fwrite(s,frame(i));
                waitbar(i/size(frame,1),bar,sprintf('Transfer progress: %dB remaining.',size(frame,1)-i));
            end
            close(bar);
            fclose(s);
        else
            [status results]=system(sprintf('./transfer /dev/tty.usbserial %s',filename));
            disp(results);
        end
    end
end