function [PRN, doppler_frequency, code_start_time, CNR] = survey_all(file, PRN, acc_length, save_file)
    tic;
    constant_h;
    constant_rcx;
    sig=load_gps_data(file,0,1);
    
    if(nargin<2 || isempty(PRN))
        PRN=1:32;
    end
    
    if(nargin<3)
        acc_length=-1;
    end
    
    if(nargin<4)
        save_file='survey';
    end
    
    satellites=length(PRN);
    doppler_frequency=zeros(satellites,1);
    code_start_time=zeros(satellites,1);
    CNR=zeros(satellites,1);
    
    h=waitbar(0,sprintf('%d satellites remaining...',satellites));
    for i=1:satellites
        [doppler_frequency(i), code_start_time(i), CNR(i)]=initial_acquisition(sig,sign(WAASCODEGN(PRN(i))-0.5),acc_length);
        if(code_start_time(i)>=0)
            fprintf('PRN %d Found: Doppler Frequency: %d, CNR = %04.2f\n',PRN(i), doppler_frequency(i), CNR(i));
        end
        waitbar(i/satellites,h,sprintf('%d satellites remaining...',satellites-i));
    end
    
    index=find(code_start_time>=0);
    PRN=PRN(index);
    doppler_frequency=doppler_frequency(index);
    code_start_time=code_start_time(index);
    CNR=CNR(index);
    
    close(h);
    disp(sprintf('Found %d satellites.',length(PRN)));
    toc;
    
    if(satellites>0)
        save(save_file,'PRN','doppler_frequency','code_start_time','CNR');
        disp(sprintf('Data saved in %s.mat.',save_file));
    end
end