function [chip_rate_kp1, err_code_k] = dll_float(i_early_k, q_early_k,...
                                                 i_late_k, q_late_k,...
                                                 w_df_kp1)
    constant_h;
    
    %Obtain magnitude of early and late I and Q vectors used for DLL
    iq_early = sqrt(i_early_k^2+q_early_k^2);
    iq_late  = sqrt(i_late_k^2+q_late_k^2);

    %Determine the amplitude of the peak
    amplitude = (iq_early+iq_late)/(2-CHIPS_EML);
    %Get the shift in chips necessary to re-center the triangle
    tau_prime = (iq_early-iq_late)/2/amplitude;
    %and the code phase error
    err_code_k = tau_prime*NUM_CHIPS;

    chip_rate_kp1 = CA_FREQ*(1+HNUM*tau_prime+w_df_kp1/2/pi/L1);
    
    return;