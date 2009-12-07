function [chip_rate_kp1, err_code_k] = dll_fixed(i_early_k, q_early_k,...
                                                 i_late_k, q_late_k,...
                                                 w_df_kp1)
    constant_h;
    
    F_S=FS;
    F_CA=CA_FREQ;
    F_L1=L1;
    
    %CHIPS_EML=0.5;
    IQ_SHIFT=9;
    IQ_WIDTH=18;
    op_width=IQ_WIDTH-IQ_SHIFT;
    
    CA_ACC_WIDTH=25;
    HNUM=5.8e-7;
    
    C=(2^CA_ACC_WIDTH*F_S/F_CA)*HNUM*(2-CHIPS_EML)/2;
    kshift=0;
    K=round(C*2^kshift);

    %Compute IQ values.
    iq_early=floor(sqrt(i_early_k^2+q_early_k^2));
    iq_late=floor(sqrt(i_late_k^2+q_late_k^2));

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
    tau_prime=dphi/(2^CA_ACC_WIDTH*F_S/F_CA*HNUM);
    dchip_rate_kp1=F_CA*tau_prime*HNUM;
    err_code_k=tau_prime*NUM_CHIPS;

    %Add nominal chipping rate and Doppler aiding to DLL.
    %Note: can't track code without Doppler aiding.
    chip_rate_kp1=dchip_rate_kp1+F_CA*(1+w_df_kp1/2/pi/F_L1);
    
    return;