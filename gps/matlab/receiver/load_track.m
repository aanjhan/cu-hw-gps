function [ip,qp,w_df]=load_track(prn,maxSecond,iqplot);
    if(nargin<2)
        maxSecond=-1;
        iqplot=0;
    elseif(nargin<3)
        iqplot=0;
    end
    
    if(~iqplot)
        file=sprintf('bit_cst_hist_%d.mat',prn);
        if(exist(file,'file')~=2)
            disp(sprintf('PRN %d not tracked.',prn));
            return;
        end
        eval(sprintf('load %s',file));
        ip=0;
        qp=0;
        w_df=w_df_overall_hist;
        second=(length(w_df)+1)/1000;
    else
        file=sprintf('PRN%d_hist_1.mat',prn);
        if(exist(file,'file')~=2)
            disp(sprintf('PRN %d not tracked.',prn));
            return;
        end
        eval(sprintf('load %s',file));
        ip=I_prompt_hist;
        qp=Q_prompt_hist;
        w_df=w_df_hist;

        second=2;
        file=sprintf('PRN%d_hist_%d.mat',prn,second);
        while(exist(file,'file')==2)
            eval(sprintf('load %s',file));
            ip=[ip;I_prompt_hist];
            qp=[qp;Q_prompt_hist];
            w_df=[w_df;w_df_hist];

            second=second+1;
            if(maxSecond>0 && second==maxSecond+1)
                break;
            end
            file=sprintf('PRN%d_hist_%d.mat',prn,second);
        end
        second=second-1;
    end

    if(second==1)s='';
    else s='s';
    end
    disp(sprintf('PRN %d tracked for %d second%s.',prn,second,s));
    disp(sprintf('Doppler: Mean=%.3f, Variance=%.3f',mean(w_df(500:end)/2/pi),var(w_df(500:end)/2/pi)));

    plot_track(prn,ip,qp,w_df,second,iqplot);
end