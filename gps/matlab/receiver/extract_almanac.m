function [almanac] = extract_almanac(data, sfindex)

sf4Pages=[2 3 4 5 7 8 9 10];
sf5Pages=1:24;

almanac=zeros(32,12);

if(mod(sfindex,100)<3)
    sfindex = sfindex+300;
end

while(sfindex<length(data)-300)
    %have to do this here for correct data inversion
    %do parity check of first subframe available
    [sfdata, flag] = parity_check(data(sfindex:sfindex+300-1),data(sfindex-2),data(sfindex-1));
    if(flag)
        error('ERROR: Almanac parity error in subframe data at index %d.', sfindex);
    end
    
    %determine the subframe ID of this data
    sfidnum = mat2int(sfdata(50:52));
    
    %Get page type.
    dataID = mat2int(sfdata(61:62));
    
    if((sfidnum==4 || sfidnum==5) && dataID==1)
        %Find SV ID.
        svID = mat2int(sfdata(63:63+5));
        
        %Extract almanac data for this subframe.
        almanac(svID,1) = svID;
        almanac(svID,1) = mat2int(sfdata(137:137+7));%Health
        almanac(svID,3) = mat2int(sfdata(69:69+15))*2^-21;%e
        almanac(svID,4) = mat2int(sfdata(91:91+7))*2^12;%toe
        almanac(svID,5) = (twoscomp2dec(sfdata(99:99+15))*2^-19+0.3)*pi;%io
        almanac(svID,6) = twoscomp2dec(sfdata(121:121+15))*pi*2^-38;%dOmega
        almanac(svID,7) = mat2int(sfdata(151:151+23))*2^-11;%sqrt(A)
        almanac(svID,8) = twoscomp2dec(sfdata(181:181+23))*pi*2^-23;%Omegao
        almanac(svID,9) = twoscomp2dec(sfdata(211:211+23))*pi*2^-23;%omega
        almanac(svID,10) = twoscomp2dec(sfdata(241:241+23))*pi*2^-23;%Mo
        almanac(svID,11) = twoscomp2dec([sfdata(271:271+7) sfdata(290:290+2)])*2^-20;%af0
        almanac(svID,12) = twoscomp2dec(sfdata(279:279+10))*2^-38;%af1
    end
    
    sfindex=sfindex+300;
end

end