function [ip,qp,w_df]=plot_track(prn,ip,qp,w_df,time,iqplot)
    if(nargin<5)
        iqplot=0;
    end
    
    sampleEnd=floor(time*1e3)+1;
    if(sampleEnd>length(w_df)) sampleEnd=length(w_df); end
    
    if(iqplot)
        ip=ip(1:sampleEnd);
        qp=qp(1:sampleEnd);
        figure;
        hold on;
        for i=1:size(ip,1)
            plot(ip(i),qp(i),'x',...
                'color',[i / size(ip,1) 0 1-(i / size(ip,1))],...
                'linewidth',1.5);
        end
        hold off;
        maxi=max(abs(ip));
        maxq=max(abs(qp));
        maxiq=max(maxi,maxq);
        axis([-maxiq maxiq -maxiq maxiq]);
        set(title(sprintf('I vs. Q - PRN %d',prn)),'FontSize',13);
        set(xlabel('I'),'FontSize',13);
        set(ylabel('Q'),'FontSize',13);
    end

    w_df=w_df(1:sampleEnd);
    figure;
    plot([0:sampleEnd-1],w_df/2/pi);
    set(title(sprintf('Doppler Frequency - PRN %d',prn)),'FontSize',13);
    set(xlabel('Time (ms)'),'FontSize',13);
    set(ylabel('Frequency (Hz)'),'FontSize',13);
end