function string=string_format(value,frac)
    if(nargin~=2)
        frac=1;
    end
    
    if(floor(value)==value)
        string=sprintf('%d',value);
    else
        format=sprintf('%%0.%df',frac);
        string=sprintf(format,value);
    end
    
    return;