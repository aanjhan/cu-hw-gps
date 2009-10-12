function [dchip_rate_kp1,err_code_k] = dll_fixed(iq_early,iq_late)
    constant_h;
    
    %CHIPS_EML=0.5;
    IQ_SHIFT=9;
    iq_width=18;
    op_width=iq_width-IQ_SHIFT;
    
    CA_ACC_WIDTH=25;
    f_ca=1.023e6;
    f_s=16.8e6;
    HNUM=5.8e-7;
    
    C=(2^CA_ACC_WIDTH*f_s/f_ca)*HNUM*(2-CHIPS_EML)/2;
    kshift=0;
    K=round(C*2^kshift);

    %Calculate eml and epl.
    eml=iq_early-iq_late;
    epl=iq_early+iq_late;
    s=sign(eml);
    eml=abs(eml);
    
    %Smart-truncate operands.
    diff_index=ceil(log2(eml))-1;
    sum_index=ceil(log2(epl))-1;
    index=max(sum_index,diff_index);
    shift=index-op_width+1;
    if(shift<0)shift=0; end
    eml=floor(eml/2^shift);
    epl=floor(epl/2^shift);
    
    %Compute code error.
    mult_result=eml*K;
    div_result=floor(mult_result/epl);
    dphi=s*floor(div_result/2^kshift);
    
    %Returns the change in chipping rate and the
    %code error in chips.
    tau_prime=dphi/(2^CA_ACC_WIDTH*f_s/f_ca*HNUM);
    dchip_rate_kp1=CA_FREQ*tau_prime*HNUM;
    err_code_k=tau_prime*NUM_CHIPS;
    
    return;