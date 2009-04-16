function packedData=GPSPack(data)
    packedData=[];
    offset=0;
    value=0;
    for i=1:length(data)
        nextValue=bitshift(bitand(TwosToPos((data(i))),7),offset,8);
        value=bitor(value,nextValue);
        offset=mod(offset+3,8);
        if(offset<3)
                packedData=[packedData;value];
            if(offset==1 || offset==2)
                value=bitshift(bitand(TwosToPos(data(i)),7),-(3-offset));
            elseif(offset==0)
                value=0;
            end
        end
    end
end

function val=TwosToPos(data)
    data=mod(data+4,8);
    twos=[5 6 7 0 1 2 3];
    val=twos(data);
end