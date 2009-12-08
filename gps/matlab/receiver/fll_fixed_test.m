function fll_fixed_test(index,log)
    CARRIER_ACC_WIDTH=27;
    ANGLE_SHIFT=9;
    F_S=16.8e6;
    ANG_TO_HZ=F_S/2^(ANGLE_SHIFT+CARRIER_ACC_WIDTH);
    
    i_k=log(index,1);
    q_k=log(index,2);
    i2q2_k=i_k^2+q_k^2;
    
    if(index>1)
        i_km1=log(index-1,1);
        q_km1=log(index-1,2);
        i2q2_km1=i_km1^2+q_km1^2;
    else
        i_km1=0;
        q_km1=0;
        i2q2_km1=1;
    end
    
    w_df_k=log(index-1,3)*ANG_TO_HZ*2*pi;
    w_df_dot_k=log(index-1,4)*ANG_TO_HZ*2*pi;
    
    [w_df_kp1, w_df_dot_kp1] = fll_fixed(i_k,q_k,...
    w_df_k, w_df_dot_k,...
    i_km1, q_km1,...
    i2q2_k, i2q2_km1);

    w_df_kp1=w_df_kp1/2/pi/ANG_TO_HZ;
    w_df_dot_kp1=w_df_dot_kp1/2/pi/ANG_TO_HZ;
    
    fprintf('dopp_inc_kp1=%d, w_df_dot_kp1=%f (%d), w_df_kp1=%f (%d)\n',...
            floor(w_df_kp1/2^ANGLE_SHIFT),w_df_dot_kp1*ANG_TO_HZ,w_df_dot_kp1,w_df_kp1*ANG_TO_HZ,w_df_kp1);
return;