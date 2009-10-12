function fll(i_prompt_k,q_prompt_k,...
        i_prompt_km1,q_prompt_km1,...
        wdf_k,wdfdot_k)
    IQ_SHIFT=11;
    iq_width=18;
    op_width=iq_width-IQ_SHIFT;
    
    PER_SHIFT=12;
    T=1e-3;
    T_fix=round(T*2^PER_SHIFT);
    ANGLE_SHIFT=9;
    FLL_CONST_SHIFT=2;
    FLL_BW=10;
    FLL_A=((1.89*FLL_BW)^2);
    FLL_B=sqrt(2)*1.89*FLL_BW;
    
    iq_prompt_k=round(sqrt(i_prompt_k^2+q_prompt_k^2));
    iq_prompt_km1=round(sqrt(i_prompt_km1^2+q_prompt_km1^2));
    
    %[I,Q]_[k,km1]>>=iq_shift
    %IQ_[k,km1]>>=iq_shift
    %dtheta=((Q_k*I_km1-I_k*Q_km1)<<ANGLE_SHIFT)/(IQ_k*IQ_km1)
    %wdfdot_kp1=wdfdot_k+(A_FLL*dtheta)>>FLL_CONST_SHIFT
    %wdf_kp1=wdf_k+wdfdot_k*T+(B_FLL*dtheta)>>FLL_CONST_SHIFT
    %
    %wdfdot and wdf are reported in *:ANGLE_SHIFT fixed point.
    
    %Print parameters.
    disp(sprintf('FLL Parameters: iq_shift=%d, angle_shift=%d, fll_const_shift=%d',IQ_SHIFT,ANGLE_SHIFT,FLL_CONST_SHIFT));
    
    %Floating point truth value.
    num=q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1;
    den=iq_prompt_k*iq_prompt_km1;
    dtheta=num/den;
    wdfdot_kp1=(wdfdot_k+FLL_A*dtheta)*2^ANGLE_SHIFT;
    wdf_kp1=(wdf_k+wdfdot_k*T+FLL_B*dtheta)*2^ANGLE_SHIFT;
    disp(sprintf('Truth: dtheta=%f, wdfdot_kp1=%f, wdf_kp1=%f.',...
        dtheta,wdfdot_kp1,wdf_kp1));
    
    %Setup fixed-point parameters.
    FLL_A=round(FLL_A*2^FLL_CONST_SHIFT);
    FLL_B=round(FLL_B*2^FLL_CONST_SHIFT);
    
    %Fixed-point without truncating IQ values
    %for speed increase and circuit complexity reduction.
    num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
    den=iq_prompt_k*iq_prompt_km1;
    div_result=floor(num/den);
    dtheta=floor(div_result/2^ANGLE_SHIFT);
    wdfdot_kp1=wdfdot_k+floor(FLL_A*div_result/2^FLL_CONST_SHIFT);
    wdf_kp1=wdf_k+...
            floor(wdfdot_k*T_fix/2^PER_SHIFT)+...
            floor(FLL_B*div_result/2^FLL_CONST_SHIFT);
    disp(sprintf('No truncate: dtheta=%f, wdfdot_kp1=%f, wdf_kp1=%f [num=%d, den=%d, div_result=%d].',...
        dtheta,wdfdot_kp1,wdf_kp1,num,den,div_result));
    
    %Fixed-point with IQ sum/diff truncation.
    index=ceil(log2(iq_prompt_k))-1;
    shift=index-op_width+1;
    if(shift<0)shift=0; end
    i_prompt_k=floor(i_prompt_k/2^shift);
    q_prompt_k=floor(q_prompt_k/2^shift);
    i_prompt_km1=floor(i_prompt_km1/2^shift);
    q_prompt_km1=floor(q_prompt_km1/2^shift);
    iq_prompt_k=floor(iq_prompt_k/2^shift);
    iq_prompt_km1=floor(iq_prompt_km1/2^shift);
    
    num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
    den=iq_prompt_k*iq_prompt_km1;
    div_result=floor(num/den);
    dtheta=floor(div_result/2^ANGLE_SHIFT);
    wdfdot_kp1=wdfdot_k+floor(FLL_A*div_result/2^FLL_CONST_SHIFT);
    wdf_kp1=wdf_k+...
            floor(wdfdot_k*T_fix/2^PER_SHIFT)+...
            floor(FLL_B*div_result/2^FLL_CONST_SHIFT);
    disp(sprintf('Truncate (%db): dtheta=%f, wdfdot_kp1=%f, wdf_kp1=%f [num=%d, den=%d, div_result=%d].',...
        op_width,dtheta,wdfdot_kp1,wdf_kp1,num,den,div_result));
    
    return;