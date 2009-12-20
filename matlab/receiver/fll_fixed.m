function [w_df_kp1, w_df_dot_kp1, err_phs_k] = fll_fixed(i_prompt_k, q_prompt_k,...
    w_df_k, w_df_dot_k,...
    i_prompt_km1, q_prompt_km1,...
    CNo_k, CNo_km1)
constant_h;

USE_TRUTH=0;
%MIXING_SIGN: -1=high-side, 1=low-side

ACC_WIDTH_TRACK=19;
CARRIER_ACC_WIDTH=27;
F_S=FS;

IQ_SHIFT=4;
PER_SHIFT=12;
ANGLE_SHIFT=9;
FLL_CONST_SHIFT=2;

op_width=ACC_WIDTH_TRACK-IQ_SHIFT;

T_fix=round(1e-3*2^PER_SHIFT);
FLL_BW=10;
FLL_A=(1.89*FLL_BW)^2;
FLL_B=sqrt(2)*1.89*FLL_BW;

%Convert Doppler values to fixed-point.
w_df_k=w_df_k/2/pi;
w_df_dot_k=w_df_dot_k/2/pi;
w_df_k=w_df_k/F_S*2^(ANGLE_SHIFT+CARRIER_ACC_WIDTH);
w_df_dot_k=w_df_dot_k/F_S*2^(ANGLE_SHIFT+CARRIER_ACC_WIDTH);

if(USE_TRUTH)
    %Calculate IQ values.
    iq_prompt_k=sqrt(CNo_k);
    iq_prompt_km1=sqrt(CNo_km1);
    
    num=q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1;
    den=iq_prompt_k*iq_prompt_km1;
    dtheta=MIXING_SIGN*num/den;
    w_df_dot_kp1=w_df_dot_k+(FLL_A*2^(ANGLE_SHIFT+CARRIER_ACC_WIDTH)/F_S/2/pi*dtheta);
    w_df_kp1=w_df_k+w_df_dot_k*T+(FLL_B*2^(ANGLE_SHIFT+CARRIER_ACC_WIDTH)/F_S/2/pi*dtheta);
    
    %Compute phase error.
    err_phs_k = -atan(q_prompt_k/i_prompt_k);
else
    FLL_A=round(FLL_A*2^FLL_CONST_SHIFT*2^CARRIER_ACC_WIDTH/F_S/2/pi);
    FLL_B=round(FLL_B*2^FLL_CONST_SHIFT*2^CARRIER_ACC_WIDTH/F_S/2/pi);
    
    %Calculate IQ values.
    iq_prompt_k=floor(sqrt(CNo_k));
    iq_prompt_km1=floor(sqrt(CNo_km1));
    
    %Fixed-point with IQ sum/diff truncation.
    index_k=ceil(log2(iq_prompt_k))-1;
    index_km1=ceil(log2(iq_prompt_km1))-1;
    index=max(index_k,index_km1);
    shift=index-op_width+1+1;%Shift extra bit to account for signed I/Q values.
    if(shift<0)shift=0; end
    
    %Set smallest possible IQ_km1 at startup.
    if(iq_prompt_km1==0)
        iq_prompt_km1=2^shift;
    end
    
    i_prompt_k=floor(i_prompt_k/2^shift);
    q_prompt_k=floor(q_prompt_k/2^shift);
    i_prompt_km1=floor(i_prompt_km1/2^shift);
    q_prompt_km1=floor(q_prompt_km1/2^shift);
    iq_prompt_k=floor(iq_prompt_k/2^shift);
    iq_prompt_km1=floor(iq_prompt_km1/2^shift);
    
    %Calculate FLL outputs.
    num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
    den=iq_prompt_k*iq_prompt_km1;
    s=MIXING_SIGN*sign(num);
    num=abs(num);
    div_result=floor(num/den);
    w_df_dot_kp1=w_df_dot_k+s*floor(FLL_A*div_result/2^FLL_CONST_SHIFT);
    w_df_kp1=w_df_k+...
        sign(w_df_dot_k)*floor(abs(w_df_dot_k)*T_fix/2^PER_SHIFT)+...
        s*floor(FLL_B*div_result/2^FLL_CONST_SHIFT);
    
    %Compute phase error using Cordic.
    err_phs_k = -atan(q_prompt_k/i_prompt_k);
end

%Re-scale fixed-point results to floating-point.
w_df_kp1=w_df_kp1*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT);
w_df_dot_kp1=w_df_dot_kp1*F_S/2^(CARRIER_ACC_WIDTH+ANGLE_SHIFT);
w_df_kp1=w_df_kp1*2*pi;
w_df_dot_kp1=w_df_dot_kp1*2*pi;

return;