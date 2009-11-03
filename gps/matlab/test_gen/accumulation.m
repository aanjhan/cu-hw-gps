MIXING_SIGN=-1;
PRN=1;
num_codes=1;
doppler=1;

[sig,t,carrier,code]=log_gen(PRN,num_codes,doppler,0);

num_samples=length(sig);

code_prompt=code;
code_early=[code_prompt(5:end);code(1:4)];
code_late=[code(end-3:end);code(1:end-4)];

carrier_i=ones_to_twos(dds_sim(27,30198989,num_samples,'cos'),3);
MIXING_SIGN*carrier_q=ones_to_twos(dds_sim(27,30198989,num_samples,'sin'),3);

sig_no_i=sig.*carrier_i;
sig_i_early=sig_no_i.*code_early;
sig_i_prompt=sig_no_i.*code_prompt;
sig_i_late=sig_no_i.*code_late;
sig_no_q=sig.*carrier_q;
sig_q_early=sig_no_q.*code_early;
sig_q_prompt=sig_no_q.*code_prompt;
sig_q_late=sig_no_q.*code_late;

acc_i=zeros(num_samples,3);
acc_i(1,:)=[sig_i_early(1) sig_i_prompt(1) sig_i_late(1)];
for i=2:num_samples
    acc_i(i,:)=acc_i(i-1,:)+[sig_i_early(i) sig_i_prompt(i) sig_i_late(i)];
end

acc_q=zeros(num_samples,3);
acc_q(1,:)=[sig_q_early(1) sig_q_prompt(1) sig_q_late(1)];
for i=2:num_samples
    acc_q(i,:)=acc_q(i-1,:)+[sig_q_early(i) sig_q_prompt(i) sig_q_late(i)];
end

index=[0:num_samples-1];
track_i=[index' sig carrier_i sig_no_i code_early code code_late acc_i]';
track_q=[index' sig carrier_q sig_no_q code_early code code_late acc_q]';
acc=[acc_i(:,1) acc_q(:,1) acc_i(:,2) acc_q(:,2) acc_i(:,3) acc_q(:,3)]';
