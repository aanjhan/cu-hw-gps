function packedData=gps_pack(data)
    packedData=zeros(ceil(length(data)*3/8),1);
    index=1;
    offset=0;
    value=0;
    for i=1:length(data)
        nextValue=bitshift(bitand(twos_to_ones(data(i),3),7),offset,8);
        value=bitor(value,nextValue);
        offset=mod(offset+3,8);
        if(offset<3)
            packedData(index)=value;
            index=index+1;
            
            if(offset==1 || offset==2)
                value=bitshift(bitand(twos_to_ones(data(i),3),7),-(3-offset));
            elseif(offset==0)
                value=0;
            end
        end
    end
end