function [signal,packedSignal]=TrackTest(PRN,send)
    %Signal length in C/A codes.
    length=3;
    
    caCode=cacodegn(PRN);
    signal=digitize_ca_prompt(caCode,length);
    signal=signal*2-1;
    
    packedSignal=GPSPack(signal);
    
    if(nargin>1 && send)
        frame=[hex2dec('FE');
               hex2dec('ED');
               1;
               0;
               2;
               hex2dec('99');
               hex2dec('00')];
        
        file=fopen(sprintf('prn_%d.dat',PRN),'wb');
        if(file<0)
            disp(sprintf('Unable to open file prn_%d.dat.',PRN));
            return;
        end
        fwrite(file,frame);
        fclose(file);
    end
end