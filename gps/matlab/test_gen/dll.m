function dll(iqe,iql)
    CHIPS_EML=0.5;
    IQ_SHIFT=8;
    IQ_WIDTH=18;
    op_width=IQ_WIDTH-IQ_SHIFT;
    
    CA_ACC_WIDTH=25;
    F_CA=1.023e6;
    F_S=16.8e6;
    HNUM=5.8e-7;
    
    DLL_SHIFT=6;
    DLL_A_SHIFT=1;
    DLL_B_SHIFT=2;
    
    %eml=(iqe-iql)
    %epl=(iqe+iql)
    %div_result=(eml<<DLL_SHIFT)/epl
    %FIXME Instead of shifting by DLL_SHIFT, just reduce
    %FIXME truncation amount on eml by DLL_SHIFT?
    %
    %tau_prime=(iqe-iql)/(iqe+iql)*(2-CHIPS_EML)/2
    %         =eml/epl*((2-CHIPS_EML)/2)
    %tau_prime_up=tau_prime*F_S/F_CA
    %            =eml/epl*((2-CHIPS_EML)*F_S/F_CA/2)
    %            =eml/epl*A
    %            =(eml/epl*A_FIX)>>DLL_A_SHIFT
    %            =(dll_result*A_FIX)>>(DLL_SHIFT+DLL_A_SHIFT)
    %A=(2-CHIPS_EML)*F_S/F_CA/2
    %A_FIX=round(A*2^DLL_A_SHIFT)
    %
    %dphi=tau_prime_up*2^CA_ACC_WIDTH*HNUM
    %    =eml/epl*(A*2^CA_ACC_WIDTH*HNUM)
    %    =eml/epl*B
    %    =(div_result*B_FIX)>>(DLL_SHIFT+DLL_B_SHIFT)
    %B=A*2^CA_ACC_WIDTH*HNUM
    %B_FIX=round(B*2^DLL_B_SHIFT)
    
    A=(2-CHIPS_EML)*F_S/F_CA/2;
    A_FIX=round(A*2^DLL_A_SHIFT);
    B=A*2^CA_ACC_WIDTH*HNUM;
    B_FIX=round(B*2^DLL_B_SHIFT);
    
    %Print parameters.
    fprintf('DLL Parameters: CHIPS_EML=%.1f, IQ_SHIFT=%d, A_SHIFT=%d, B_SHIFT=%d, HNUM=%e\n',...
        CHIPS_EML,IQ_SHIFT,DLL_A_SHIFT,DLL_B_SHIFT,HNUM);
    
    %Floating point truth value.
    eml=iqe-iql;
    epl=iqe+iql;
    div_result=eml/epl;
    tau_prime_up=div_result*A;
    dphi=div_result*B;
    chips=round(tau_prime_up);
    fprintf('Truth: shift by %d (%.10f) chips - dphi=%.6f.\n',chips,tau_prime_up,dphi);
    
    %Fixed-point without truncating IQ values
    %for speed increase and circuit complexity reduction.
    eml=iqe-iql;
    epl=iqe+iql;
    s=sign(eml);
    eml=abs(eml);
    div_result=floor((eml*2^DLL_SHIFT)/epl);
    tau_prime_up=s*floor((div_result*A_FIX+2^(DLL_SHIFT+DLL_A_SHIFT-1))/2^(DLL_SHIFT+DLL_A_SHIFT));
    dphi=s*floor((div_result*B_FIX+2^(DLL_SHIFT+DLL_B_SHIFT-1))/2^(DLL_SHIFT+DLL_B_SHIFT));
    chipsf=s*(div_result*A_FIX)/2^(DLL_SHIFT+DLL_A_SHIFT);
    fprintf('No truncate: shift by %d (%.10f) chips - dphi=%.6f.\n',...
        tau_prime_up,chipsf,dphi);
    fprintf('             [eml=%d, epl=%d, div=%d]\n',...
        eml,epl,div_result);
    
    %Fixed-point with IQ sum/diff truncation.
    eml=iqe-iql;
    epl=iqe+iql;
    s=sign(eml);
    eml=abs(eml);
    diff_index=ceil(log2(eml))-1;
    sum_index=ceil(log2(epl))-1;
    index=max(sum_index,diff_index);
    shift=index-op_width+1;
    if(shift<0)shift=0; end
    eml=floor(eml/2^shift);
    epl=floor(epl/2^shift);
    
    div_result=floor((eml*2^DLL_SHIFT)/epl);
    tau_prime_up=s*floor((div_result*A_FIX+2^(DLL_SHIFT+DLL_A_SHIFT-1))/2^(DLL_SHIFT+DLL_A_SHIFT));
    dphi=s*floor((div_result*B_FIX+2^(DLL_SHIFT+DLL_B_SHIFT-1))/2^(DLL_SHIFT+DLL_B_SHIFT));
    chipsf=s*(div_result*A_FIX)/2^(DLL_SHIFT+DLL_A_SHIFT);
    fprintf('No truncate: shift by %d (%.10f) chips - dphi=%.6f.\n',...
        tau_prime_up,chipsf,dphi);
    fprintf('             [eml=%d, epl=%d, div=%d]\n',...
        eml,epl,div_result);
    
    %Plot amplitude triangle.
    amp=(iqe+iql)/(2-CHIPS_EML);
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