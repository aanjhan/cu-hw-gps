function [w_df_kp1, w_df_dot_kp1] = fll_fixed(i_prompt_k, q_prompt_k,...
                                              w_df_k, w_df_dot_k,...
                                              i_prompt_km1, q_prompt_km1,...
                                              CNo_k, CNo_km1)
    constant_h;
    
    USE_TRUTH=0;
    %MIXING_SIGN: -1=high-side, 1=low-side

    IQ_SHIFT=11;
    PER_SHIFT=12;
    ANGLE_SHIFT=9;
    FLL_CONST_SHIFT=2;

    iq_width=18;
    op_width=iq_width-IQ_SHIFT;

    T_fix=round(1e-3*2^PER_SHIFT);
    FLL_BW=10;
    FLL_A=(1.89*FLL_BW)^2;
    FLL_B=sqrt(2)*1.89*FLL_BW;
    FLL_A_FIXED=round(FLL_A*2^FLL_CONST_SHIFT);
    FLL_B_FIXED=round(FLL_B*2^FLL_CONST_SHIFT);

    %Convert Doppler values to fixed-point.
    w_df_dot_k=w_df_dot_k*2^ANGLE_SHIFT;
    w_df_k=w_df_k*2^ANGLE_SHIFT;

    if(USE_TRUTH)
      %Calculate IQ values.
      iq_prompt_k=sqrt(CNo_k);
      iq_prompt_km1=sqrt(CNo_km1);

      num=q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1;
      den=iq_prompt_k*iq_prompt_km1;
      dtheta=MIXING_SIGN*num/den;
      w_df_dot_kp1=w_df_dot_k+(FLL_A*dtheta/2^FLL_CONST_SHIFT)*2^ANGLE_SHIFT;
      w_df_kp1=w_df_k+w_df_dot_k*T+(FLL_B*dtheta/2^FLL_CONST_SHIFT)*2^ANGLE_SHIFT;
    else
      %Calculate IQ values.
      iq_prompt_k=round(sqrt(CNo_k));
      iq_prompt_km1=round(sqrt(CNo_km1));
      
      %Smart-truncate I/Q values.
      index=ceil(log2(iq_prompt_k))-1;
      shift=index-op_width+1;
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
    
      num=(q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)*2^ANGLE_SHIFT;
      den=iq_prompt_k*iq_prompt_km1;
      div_result=MIXING_SIGN*floor(num/den);
      w_df_dot_kp1=w_df_dot_k+floor(FLL_A_FIXED*div_result/2^FLL_CONST_SHIFT);
      w_df_kp1=w_df_k+...
               floor(w_df_dot_k*T_fix/2^PER_SHIFT)+...
               floor(FLL_B_FIXED*div_result/2^FLL_CONST_SHIFT);
    end

    w_df_dot_kp1=w_df_dot_kp1/2^ANGLE_SHIFT;
    w_df_kp1=w_df_kp1/2^ANGLE_SHIFT;

    return;