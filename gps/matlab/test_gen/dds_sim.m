function out=dds_sim(width,inc,samples,lut)
    M=width;
    
    if(nargin<4)
        lut='cos';
    end
    K=4;
    lut=lookup_table(lut,3,K);
    
    acc=0;
    out=zeros(samples,1);
    for i=1:samples
        index=bitshift(acc,-(M-K));
        out(i)=lut(index+1);

        acc=mod(acc+inc,2^M);
    end
end