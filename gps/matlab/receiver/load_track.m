function [ip,qp,w_df,snr_floor]=load_track(prns,maxSecond,iqplot,compute_snr_floor);
    if(nargin<2)
        maxSecond=-1;
        iqplot=0;
        compute_snr_floor=0;
    elseif(nargin<3)
        iqplot=0;
        compute_snr_floor=0;
    elseif(nargin<4)
        compute_snr_floor=0;
    end
    
    for prn=prns
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

            second=1;
            file=sprintf('PRN%d_hist_%d.mat',prn,second+1);
            while(exist(file,'file')==2 &&...
                    (maxSecond<0 || second+1<=maxSecond))
                second=second+1;

                eval(sprintf('load %s',file));
                ip=[ip;I_prompt_hist];
                qp=[qp;Q_prompt_hist];
                w_df=[w_df;w_df_hist];

                if(maxSecond>0 && second==maxSecond+1)
                    break;
                end
                file=sprintf('PRN%d_hist_%d.mat',prn,second+1);
            end
        end

        if(second==1)s='';
        else s='s';
        end
        disp(sprintf('PRN %d tracked for %d second%s.',prn,second,s));
        disp(sprintf('Doppler: Mean=%.3f, Variance=%.3f',mean(w_df(500:end)/2/pi),var(w_df(500:end)/2/pi)));
        
        if(compute_snr_floor)
            zbar=mean(I_prompt_hist.^2+Q_prompt_hist.^2);
            sigz=var(I_prompt_hist.^2+Q_prompt_hist.^2);
            snr_floor=zbar-sqrt(zbar^2-sigz);
            disp(sprintf('SNR Floor: %.3f',snr_floor));
        end

        plot_track(prn,ip,qp,w_df,second,iqplot);
    end
end