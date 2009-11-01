function [w_df_kp1, w_df_dot_kp1, err_phs_k] = fll_float(i_prompt_k, q_prompt_k,...
                                                         w_df_k, w_df_dot_k,...
                                                         i_prompt_km1, q_prompt_km1,...
                                                         CNo_k, CNo_km1)
    constant_h;

    %This is the phase error
    err_phs_k = -atan(q_prompt_k/i_prompt_k);

    %Get the magnitudes of I,Q k and km1
%     IQknorm = sqrt(CNo_k);
%     IQkm1norm = sqrt(CNo_km1);

    %determine the angle by which I and Q have rotated from km1 to k
    % rotation_angle = -(Q_prompt_k*I_prompt_km1-I_prompt_k*Q_prompt_km1)/IQknorm/IQkm1norm;
    IQ_k=[i_prompt_k q_prompt_k 0];
    IQ_km1=[i_prompt_km1 q_prompt_km1 0];
    %Rotation Angle = (-/+)atan((IQ_km1 cross IQ_k)/(IQ_k dot IQ_km1))
    % -> high-side=-, low-side=+
    rotation_angle = MIXING_SIGN*atan((q_prompt_k*i_prompt_km1-i_prompt_k*q_prompt_km1)/dot(IQ_k, IQ_km1));
    % rotation_angle = rotation_angle(3);

    %the angle rot_angle, times a constant, plus the previous doppler shift rate, is the
    %next doppler shift rate
    w_df_dot_kp1 = w_df_dot_k+A_FLL*rotation_angle;

    %the next doppler shift estimate is a function of the previous estimate,
    %plus the doppler shift rate over the accumulation period, plus the angle
    %rot_angle times another constant
    w_df_kp1 = w_df_k+w_df_dot_k*T+B_FLL*rotation_angle;

    return;