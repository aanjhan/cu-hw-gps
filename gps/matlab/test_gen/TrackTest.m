function [signal,packedSignal]=TrackTest(PRN,send)
    %Signal length in C/A codes.
    length=1;
    
    caCode=cacodegn(PRN);
    signal=digitize_ca_prompt(caCode,length);
    signal=signal*2-1;
    
    packedSignal=GPSPack(signal);
    
    if(nargin>1 && send)
        frame=[hex2dec('FE');
               hex2dec('ED');
               1;
               floor(size(packedSignal,1)/2^8);
               mod(size(packedSignal,1),2^8);
               packedSignal];
        
        file=fopen(sprintf('prn_%d.dat',PRN),'wb');
        if(file<0)
            disp(sprintf('Unable to open file prn_%d.dat.',PRN));
            return;
        end
        fwrite(file,frame);
        fclose(file);
        
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
        end
    end
end