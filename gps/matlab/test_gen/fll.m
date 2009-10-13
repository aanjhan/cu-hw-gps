function fll(i_prompt_k,q_prompt_k,...
        i_prompt_km1,q_prompt_km1,...
        w_df_k,w_df_dot_k)
    ACC_WIDTH_TRACK=19;
    CARRIER_ACC_WIDTH=27;
    F_S=16.8e6;
    
    IQ_SHIFT=11;
    PER_SHIFT=12;
    ANGLE_SHIFT=9;
    FLL_CONST_SHIFT=2;
    W_DF_TO_INC_SHIFT=8;
    
    op_width=ACC_WIDTH_TRACK-IQ_SHIFT;
    W_DF_TO_INC=(180*2^(CARRIER_ACC_WIDTH-ANGLE_SHIFT)/pi/F_S);
    
    T=1e-3;
    T_fix=round(T*2^PER_SHIFT);
    FLL_BW=10;
    FLL_A=((1.89*FLL_BW)^2);
    FLL_B=sqrt(2)*1.89*FLL_BW;
    
    iq_prompt_k=round(sqrt(i_prompt_k^2+q_prompt_k^2));
    iq_prompt_km1=round(sqrt(i_prompt_km1^2+q_prompt_km1^2));
    
    %[I,Q]_[k,km1]>>=iq_shift
    %IQ_[k,km1]>>=iq_shift
    %dtheta=((Q_k*I_km1-I_k*Q_km1)<<ANGLE_SHIFT)/(IQ_k*IQ_km1)
    %w_df_dot_kp1=w_df_dot_k+(A_FLL*dtheta)>>FLL_CONST_SHIFT
    %w_df_kp1=w_df_k+w_df_dot_k*T+(B_FLL*dtheta)>>FLL_CONST_SHIFT
    %dopp_inc=(w_df_float*180/pi)*2^CARRIER_ACC_WIDTH/f_s
    %        =w_df_float*(180*2^CARRIER_ACC_WIDTH/pi/f_s)
    %        =(w_df/2^ANGLE_SHIFT)*(180*2^CARRIER_ACC_WIDTH/pi/f_s)
    %        =w_df*(180*2^(CARRIER_ACC_WIDTH-ANGLE_SHIFT)/pi/f_s)
    %
    %w_df_dot and w_df are reported in *:ANGLE_SHIFT fixed point.
    
    %Print parameters.
    disp(sprintf('FLL Parameters: iq_shift=%d, angle_shift=%d, fll_const_shift=%d',IQ_SHIFT,ANGLE_SHIFT,FLL_CONST_SHIFT));
    disp(sprintf('                iq_prompt_k=%d, iq_prompt_km1=%d',iq_prompt_k,iq_prompt_km1));
    
    %Floating point truth value.
    num=q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1;
    den=iq_prompt_k*iq_prompt_km1;
    dtheta=num/den;
    w_df_dot_kp1=(w_df_dot_k+FLL_A*dtheta)*2^ANGLE_SHIFT;
    w_df_kp1=(w_df_k+w_df_dot_k*T+FLL_B*dtheta)*2^ANGLE_SHIFT;
    dopp_inc_kp1=w_df_kp1*W_DF_TO_INC;
    disp(sprintf('Truth: dtheta=%f, w_df_dot_kp1=%f, w_df_kp1=%f, dopp_inc_kp1=%f.',...
        dtheta,w_df_dot_kp1,w_df_kp1,dopp_inc_kp1));
    
    %Setup fixed-point parameters.
    FLL_A=round(FLL_A*2^FLL_CONST_SHIFT);
    FLL_B=round(FLL_B*2^FLL_CONST_SHIFT);
    
    %Fixed-point without truncating IQ values
    %for speed increase and circuit complexity reduction.
    num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
    den=iq_prompt_k*iq_prompt_km1;
    s=sign(num);
    num=abs(num);
    div_result=floor(num/den);
    dtheta=floor(div_result/2^ANGLE_SHIFT);
    w_df_dot_kp1=w_df_dot_k+s*floor(FLL_A*div_result/2^FLL_CONST_SHIFT);
    w_df_kp1=w_df_k+...
            sign(w_df_dot_k)*floor(abs(w_df_dot_k)*T_fix/2^PER_SHIFT)+...
            s*floor(FLL_B*div_result/2^FLL_CONST_SHIFT);
    dopp_inc_kp1=s*floor(abs(w_df_kp1)*round(W_DF_TO_INC*2^W_DF_TO_INC_SHIFT)/2^W_DF_TO_INC_SHIFT);
    disp(sprintf('No truncate: dtheta=%f, w_df_dot_kp1=%d, w_df_kp1=%d, dopp_inc_kp1=%d [num=%d, den=%d, div_result=%d].',...
        dtheta,w_df_dot_kp1,w_df_kp1,dopp_inc_kp1,num,den,div_result));
    
    %Fixed-point with IQ sum/diff truncation.
    index_k=ceil(log2(iq_prompt_k))-1;
    index_km1=ceil(log2(iq_prompt_km1))-1;
    index=max(index_k,index_km1);
    shift=index-op_width+1+1;%Shift extra bit to account for signed I/Q values.
    if(shift<0)shift=0; end
    i_prompt_k=floor(i_prompt_k/2^shift);
    q_prompt_k=floor(q_prompt_k/2^shift);
    i_prompt_km1=floor(i_prompt_km1/2^shift);
    q_prompt_km1=floor(q_prompt_km1/2^shift);
    iq_prompt_k=floor(iq_prompt_k/2^shift);
    iq_prompt_km1=floor(iq_prompt_km1/2^shift);
    
    num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
    den=iq_prompt_k*iq_prompt_km1;
    s=sign(num);
    num=abs(num);
    div_result=floor(num/den);
    dtheta=floor(div_result/2^ANGLE_SHIFT);
    w_df_dot_kp1=w_df_dot_k+s*floor(FLL_A*div_result/2^FLL_CONST_SHIFT);
    w_df_kp1=w_df_k+...
            sign(w_df_dot_k)*floor(abs(w_df_dot_k)*T_fix/2^PER_SHIFT)+...
            s*floor(FLL_B*div_result/2^FLL_CONST_SHIFT);
    dopp_inc_kp1=s*floor(abs(w_df_kp1)*round(W_DF_TO_INC*2^W_DF_TO_INC_SHIFT)/2^W_DF_TO_INC_SHIFT);
    disp(sprintf('Truncate (%db): dtheta=%f, w_df_dot_kp1=%d, w_df_kp1=%d, dopp_inc_kp1=%d [num=%d, den=%d, div_result=%d].',...
        op_width,dtheta,w_df_dot_kp1,w_df_kp1,dopp_inc_kp1,num,den,div_result));
    disp(sprintf('               [index=%d, shift=%d, iq_k_trunc=%d, iq_km1_trunc=%d]',...
        index,shift,iq_prompt_k,iq_prompt_km1));
    disp(sprintf('               [i_k_trunc=%d, q_k_trunc=%d, i_km1_trunc=%d, q_km1_trunc=%d]',...
        i_prompt_k,q_prompt_k,i_prompt_km1,q_prompt_km1));
    
    return;