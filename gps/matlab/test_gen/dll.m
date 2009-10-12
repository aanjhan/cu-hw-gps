function dll(iqe,iql)
    chips_eml=0.5;
    iq_shift=9;
    iq_width=18;
    op_width=iq_width-iq_shift;
    
    ca_acc_width=25;
    f_ca=1.023e6;
    f_s=16.8e6;
    HNUM=5.8e-7;
    
    %eml=(iqe-iql)
    %epl=(iqe+iql)
    %tau_prime=(iqe-iql)/(iqe+iql)*(2-chips_eml)/2
    %         =eml/epl*((2-chips_eml)/2)
    %tau_prime_up=tau_prime*f_s/f_ca
    %            =eml/epl*((2-chips_eml)*f_s/f_ca/2)
    %dphi=tau_prime_up*2^ca_acc_width*HNUM
    %    =eml/epl*(2^ca_acc_width*(2-chips_eml)*f_s/f_ca/2*HNUM)
    %    =eml/epl*C
    %    =(eml/epl*K)>>kshift
    %C=2^ca_acc_width*HNUM*(2-chips_eml)*f_s/f_ca/2
    %K=C*2^kshift (fixed-point)
    
    inc_to_chips=1/(2^ca_acc_width*HNUM);
    C=2^ca_acc_width*HNUM*(2-chips_eml)*f_s/f_ca/2;
    kshift=0;
    K=round(C*2^kshift);
    eml=iqe-iql;
    epl=iqe+iql;
    
    %Print parameters.
    disp(sprintf('DLL Parameters: chips_eml=%.1f, iq_shift=%d, k_shift=%d, HNUM=%e',chips_eml,iq_shift,kshift,HNUM));
    
    %Floating point truth value.
    dphi=eml/epl*C;
    chipsf=dphi*inc_to_chips;
    chips=round(chipsf);
    disp(sprintf('Truth: shift by %d (%.10f) chips - dphi=%.6f.',chips,chipsf,dphi));
    
    %Fixed-point without truncating IQ values
    %for speed increase and circuit complexity reduction.
    s=sign(eml);
    eml=abs(eml);
    mult_result=eml*K;
    div_result=floor(mult_result/epl);
    dphi=s*floor(div_result/2^kshift);
    chips=s*floor(div_result/2^kshift*inc_to_chips);
    chipsf=s*(eml*K/epl)/2^kshift*inc_to_chips;
    disp(sprintf('No truncate: shift by %d (%.10f) chips - dphi=%.6f. [eml=%d, epl=%d, mult=%d, div=%d]',...
        chips,chipsf,dphi,eml,epl,mult_result,div_result));
    
    %Fixed-point with IQ sum/diff truncation.
    eml=iqe-iql;
    epl=iqe+iql;
    diff_index=ceil(log2(eml))-1;
    sum_index=ceil(log2(epl))-1;
    index=max(sum_index,diff_index);
    shift=index-op_width+1;
    if(shift<0)shift=0; end
    s=sign(eml);
    eml=abs(eml);
    eml=floor(eml/2^shift);
    epl=floor(epl/2^shift);
    mult_result=eml*K;
    div_result=floor(mult_result/epl);
    dphi=s*floor(div_result/2^kshift);
    chips=s*floor(div_result/2^kshift*inc_to_chips);
    chipsf=s*(eml*K/epl)/2^kshift*inc_to_chips;
    disp(sprintf('Truncate (%db): shift by %d (%.10f) chips - dphi=%.6f. [eml=%d, epl=%d, mult=%d, div=%d]',...
        shift,chips,chipsf,dphi,eml,epl,mult_result,div_result));
    
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
    stem(x(prompt),tri(prompt),'k');
    hold off;
    
    return;