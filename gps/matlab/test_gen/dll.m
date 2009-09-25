function dll(iqe,iql)
    chips_eml=0.5;
    
    %eml=(iqe-iql)
    %epl=(iqe+iql)
    %tau_prime=(iqe-iql)/(iqe+iql)*(2-chips_eml)/2
    %         =eml/epl*((2-chips_eml)/2)
    %tau_prime_up=tau_prime*f_s/f_ca
    %            =eml/epl*((2-chips_eml)*f_s/f_ca/2)
    %            =eml/epl*C
    %            =(eml/epl*K)>>kshift
    %C=(2-chips_eml)*f_s/f_ca/2
    %K=C*2^kshift (fixed-point)
    
    C=16.8*(2-chips_eml)/1.023/2;
    kshift=8;
    K=round(C*2^kshift);
    eml=iqe-iql;
    epl=iqe+iql;
    
    %Floating point truth value.
    chipsf=eml/epl*C;
    chips=round(chipsf);
    disp(sprintf('Truth: shift by %d (%.10f) chips.',chips,chipsf));
    
    %Fixed-point without truncating I2Q2 values
    %for speed increase and circuit complexity reduction.
    mult_result=eml*K;
    div_result=floor(mult_result/epl);
    chips=floor(div_result/2^kshift);
    chipsf=(eml*K/epl)/2^kshift;
    disp(sprintf('No truncate: shift by %d (%.10f) chips. [eml=%d, epl=%d, mult=%d, div=%d]',...
        chips,chipsf,eml,epl,mult_result,div_result));
    
    %Fixed-point with I2Q2 sum/diff truncation.
    eml=iqe-iql;
    epl=iqe+iql;
    diff_index=ceil(log2(eml))-1;
    sum_index=ceil(log2(epl))-1;
    index=max(sum_index,diff_index);
    shift=index-13;
    if(shift<0)shift=0; end
    s=sign(eml);
    eml=abs(eml);
    eml=floor(eml/2^shift);
    epl=floor(epl/2^shift);
    mult_result=eml*K;
    div_result=floor(mult_result/epl);
    chips=s*floor(div_result/2^kshift);
    chipsf=s*(eml*K/epl)/2^kshift;
    disp(sprintf('Truncate (%db): shift by %d (%.10f) chips. [eml=%d, epl=%d, mult=%d, div=%d]',...
        shift,chips,chipsf,eml,epl,mult_result,div_result));
    
    %Plot amplitude triangle.
    amp=(iqe+iql)/(2-chips_eml);
    x=linspace(-16.8,16.8,10000);
    tri=[linspace(0,amp,length(x)/2) linspace(amp,0,length(x)/2)];
    plot(x,tri,'b');
    hold on;
    [val,early]=min(abs(tri(length(tri)/2:end)-iqe));
    early=early+length(tri)/2;
    stem(x(early),iqe,'g');
    [val,late]=min(abs(tri(1:length(tri)/2)-iql));
    stem(x(late),iql,'r');
    prompt=round((early+late)/2);
    stem(x(prompt),tri(prompt),'y');
    hold off;
    
    return;