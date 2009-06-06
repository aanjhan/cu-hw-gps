function [results,dds_results]=test_results(PRN,doppler)
    constant_rcx;
    
    [signal,carrier,code,t]=test_gen(PRN,0);
    
    f_carrier=FC+doppler;
    carrier_i=round(cos(2*pi*f_carrier*t)'*3);
    carrier_q=round(sin(2*pi*f_carrier*t)'*3);
    
    I=sum(signal.*carrier_i.*code);
    Q=sum(signal.*carrier_q.*code);
    I2Q2=I.^2+Q.^2;
    results=[I Q I2Q2];
    
    disp(sprintf('Actual: I=%d (0x%X), Q=%d (0x%X), I2Q2=%d (0x%X)',I,I,Q,Q,I2Q2,I2Q2));
    
    dds_inc=30198989+round(7.99*doppler);
    carrier_i_dds=ones_to_twos(dds_sim(27,dds_inc,length(signal),'cos'),3);
    carrier_q_dds=ones_to_twos(dds_sim(27,dds_inc,length(signal),'sin'),3);
    
%     acc=zeros(length(signal),1);
%     I=signal.*carrier_i_dds.*code;
%     for i=1:length(signal)
%         acc(i)=sum(I(1:i));
%     end
    
    I=sum(signal.*carrier_i_dds.*code);
    Q=sum(signal.*carrier_q_dds.*code);
    I2Q2=I.^2+Q.^2;
    dds_results=[I Q I2Q2];
    
    disp(sprintf('DDS: I=%d (0x%X), Q=%d (0x%X), I2Q2=%d (0x%X)',I,I,Q,Q,I2Q2,I2Q2));
end