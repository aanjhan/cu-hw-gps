MIXING_SIGN=-1;
PRN=1;
num_codes=1.1;
doppler=1;
F_S=16.8e6;
T_CA=1e-3;
NUM_CHIPS=F_S*T_CA;

[sig,t,carrier,code_prompt]=log_gen(PRN,num_codes+4/NUM_CHIPS,doppler,0);
sig=sig(1:end-4);
t=t(1:end-4);
carrier=carrier(1:end-4);
num_samples=num_codes*NUM_CHIPS;

code=digitize_ca_prompt(cacodegn(PRN),1)*2-1;

code_late=[code(end-3:end);code_prompt(1:num_codes*NUM_CHIPS-4)];
code_early=code_prompt(5:end);
code_prompt=code_prompt(1:end-4);

carrier_i=ones_to_twos(dds_sim(27,30198989,num_samples,'cos'),3);
carrier_q=MIXING_SIGN*ones_to_twos(dds_sim(27,30198989,num_samples,'sin'),3);

sig_no_i=sig.*carrier_i;
sig_i_early=sig_no_i.*code_early;
sig_i_prompt=sig_no_i.*code_prompt;
sig_i_late=sig_no_i.*code_late;
sig_no_q=sig.*carrier_q;
sig_q_early=sig_no_q.*code_early;
sig_q_prompt=sig_no_q.*code_prompt;
sig_q_late=sig_no_q.*code_late;

acc_i=zeros(num_samples,3);
for i=1:num_samples
    if(mod(i,16800)==1)
        acc_i(i,:)=[sig_i_early(i) sig_i_prompt(i) sig_i_late(i)];
    else
        acc_i(i,:)=acc_i(i-1,:)+[sig_i_early(i) sig_i_prompt(i) sig_i_late(i)];
    end
end

acc_q=zeros(num_samples,3);
for i=1:num_samples
    if(mod(i,16800)==1)
        acc_q(i,:)=[sig_q_early(i) sig_q_prompt(i) sig_q_late(i)];
    else
        acc_q(i,:)=acc_q(i-1,:)+[sig_q_early(i) sig_q_prompt(i) sig_q_late(i)];
    end
end

index=[0:num_samples-1];
track_i=[index' sig carrier_i sig_no_i code_early code_prompt code_late acc_i]';
track_q=[index' sig carrier_q sig_no_q code_early code_prompt code_late acc_q]';
acc=[acc_i(:,1) acc_q(:,1) acc_i(:,2) acc_q(:,2) acc_i(:,3) acc_q(:,3)]';
