%DDS Parameters
%  M - Accumulator Width
%  N - Phase Width
%  fref - Reference Frequency
M=24;
N=20;
fref=16.8e6;

%Output Parameters
%  K - Index Width
%  J - Output Width
K=4;
J=3;

%System Parameters
%  ftarget - Target Frequency
%  dphi - Phase Value For Target
ftarget=1.023e6;
dphi=1021613;

%Generate Output Lookup Table
lut=floor((2^J-1)*sin(2*pi*(0:2^J-1)/2^J));

%Generate Target
tmax=50/ftarget;
t=[0:1/fref:tmax];
target=(2^J-1)*sin(2*pi*ftarget*t);

%Perform DDS
acc=0;
out=zeros(length(t),1);
for i=1:length(t)
    index=bitshift(acc,-(M-(K-1)));
    out(i)=lut(index+1);
    
    acc=mod(acc+dphi,2^M);
end

subplot(2,1,1);
plot(t,out,t,target,'--');
subplot(2,1,2);
ssf=linspace(0,fref/2,length(out)/2);
out_fft=fft(out);
target_fft=fft(target);
plot(ssf,abs(out_fft(1:length(out)/2)),...
    ssf,abs(target_fft(1:length(out)/2)));