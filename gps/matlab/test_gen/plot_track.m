function [ip,qp,w_df]=plot_track(prn,ip,qp,w_df,time);
    sampleEnd=floor(time*1e3)+1;
    if(sampleEnd>length(ip)) sampleEnd=length(ip); end
    
    ip=ip(1:sampleEnd);
    qp=qp(1:sampleEnd);
    w_df=w_df(1:sampleEnd);
    
    figure;
    plot(ip,qp,'.');
    set(title(sprintf('I vs. Q - PRN %d',prn)),'FontSize',13);
    set(xlabel('I'),'FontSize',13);
    set(ylabel('Q'),'FontSize',13);

    figure;
    plot([0:sampleEnd-1],w_df/2/pi);
    set(title(sprintf('Doppler Frequency - PRN %d',prn)),'FontSize',13);
    set(xlabel('Time (ms)'),'FontSize',13);
    set(ylabel('Frequency (Hz)'),'FontSize',13);
end