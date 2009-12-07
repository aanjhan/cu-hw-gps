function test_almanac()
    constant;
    constant_h;
    constant_rcx;
    
    load ephem.asc;
    load almanac.asc;
    load obs.asc;
    
    %Restrict healthy satellites only.
    healthy=almanac(find(almanac(:,2)==0),1);
    ephemIndex=find(ismember(ephem(:,1),healthy)==1);
    ephem=ephem(ephemIndex,:);
    
    %Use almanac data from satellites in ephemeris data.
    SVs=find(ismember(almanac(:,1),ephem(:,1))==1);
    almanac=almanac(SVs,:);
    almanac=almanac(find(almanac(:,2)==0),:);
    ephema=ephem_from_almanac(almanac);
    
    %Use selected pseudoranges.
    index=find(ismember(obs(1,3:2:end),SVs)==1);
    pseudo_range=obs(:,index*2+2);
    
%     samples=[obs(1,1) obs(end,1)];
    samples=obs(:,1);
    ds=zeros(size(ephem,1)*length(samples),4);
    ddopp=zeros(size(ephem,1)*length(samples),1);
    for s=1:length(samples)
        sample=samples(s);
        time=obs(sample,2);
        
        %Find ephemeris and almanac satellites.
%        subplot(1,length(samples),s);
        [satpose,satvele]=findsat(ephem,time);
        [satposa,satvela]=findsat(ephema,time);
        satposa(:,1)=satposa(:,1)+100;
        elaz=elevazim([satpose;satposa],ecef([65.116936,-147.4347125,0]));
%         plotsat(elaz);
%         set(title('Satellite Position Errors'),'FontSize',17);
%         set(xlabel('Black - Ephemeris, Red - Almanac'),'FontSize',17);
    
        %Positional errors.
%         disp(sprintf('Sample %d (%d s)',sample,time));
%         disp(' Satellite position error:');
        for i=1:size(satpose,1)
            index=(s-1)*size(satpose,1)+i;
            ds(index,1)=ds(index,1)+sqrt(sum((satpose(i,3:5)-satposa(i,3:5)).^2));
            ds(index,2:4)=ds(index,2:4)+abs(satpose(i,3:5)-satposa(i,3:5));
%             disp(sprintf('   PRN %d: diff=%.3f, dx=%.3f, dy=%.3f, dz=%.3f',...
%                 satpose(i,1),...
%                 sqrt(sum((satpose(i,3:5)-satposa(i,3:5)).^2)),...
%                 satpose(i,3)-satposa(i,3),...
%                 satpose(i,4)-satposa(i,4),...
%                 satpose(i,5)-satposa(i,5)));
        end
        
%         [in_sig, fid, fileNo] = load_gps_data('ece584_60sec.bin',0,1);
%         [PRN, doppler_frequency, code_start_time, CNR]=aided_acquisition(in_sig,ecef([65.116936,-147.4347125,0]),488500);
%         for prn=1:length(PRN)
%             %if the signal was not found, quit this satellite
%             if(CNR(prn)<CNO_MIN || code_start_time(prn) < 0)  
%                 fprintf('Warning: Initial Acquisition failed: PRN %02d not found in data set\n',PRN(prn))
%                 fprintf('Doppler Frequency: %d   Code Start Time: %f    CNR: %f\n',doppler_frequency(prn), code_start_time(prn), CNR(prn));
%             %otherwise track the satellite
%             else 
%                 fprintf('PRN %d Found: Doppler Frequency: %d, CNR = %04.2f, cst=%f\n',PRN(prn), doppler_frequency(prn), CNR(prn), code_start_time(prn));
%             end
%         end

         %Calculate Doppler shift.
         DOPPLER_OFFSET = 0;%1000;
         obsLatLong=[65.116936,-147.4347125,524.7];
         obsPos=ecef(obsLatLong);
         vObs=OmegaE*norm(obsPos)*cos(obsLatLong(1)*pi/180)*[-sin(obsLatLong(2)*pi/180) cos(obsLatLong(2)*pi/180) 0];
         
         %Almanac Doppler
         satPos=satposa(:,3:5);
         satVel=satvela(:,2:4);
         rho=sqrt(sum((satPos-ones(size(satPos,1),1)*obsPos).^2,2));
         velpe=vObs;
         rhohat=(satPos-ones(size(satPos,1),1)*obsPos)./(rho*ones(1,3));
         dopp_almanac=zeros(size(satPos,1),1);
         for i=1:size(satPos,1)
             dopp_almanac(i)=f_L1*((-rhohat(i,:)*(satVel(i,:)-velpe)')/(c+rhohat(i,:)*(satVel(i,:)-velpe)'))-DOPPLER_OFFSET;
         end
         
         %Ephemeris Doppler
         satPos=satpose(:,3:5);
         satVel=satvele(:,2:4);
         rho=sqrt(sum((satPos-ones(size(satPos,1),1)*obsPos).^2,2));
         velpe=vObs;
         rhohat=(satPos-ones(size(satPos,1),1)*obsPos)./(rho*ones(1,3));
         dopp_ephem=zeros(size(satPos,1),1);
         for i=1:size(satPos,1)
             dopp_ephem(i)=f_L1*((-rhohat(i,:)*(satVel(i,:)-velpe)')/(c+rhohat(i,:)*(satVel(i,:)-velpe)'))-DOPPLER_OFFSET;
         end
         
         index=(s-1)*size(satpose,1)+1;
         ddopp(index:index+size(satPos,1)-1)=dopp_almanac-dopp_ephem;
    end
    
    [in_sig, fid, fileNo] = load_gps_data('ece584_2sec.bin',0,1);
    [PRN, doppler_frequency, code_start_time, CNR]=aided_acquisition(in_sig,ecef([65.116936,-147.4347125,0]),488500,1);
    for prn=1:length(PRN)
        %if the signal was not found, quit this satellite
        if(CNR(prn)<CNO_MIN || code_start_time(prn) < 0)
            fprintf('Warning: Initial Acquisition failed: PRN %02d not found in data set\n',PRN(prn))
        else
            fprintf('PRN %d Found: Doppler Frequency: %d, CNR = %04.2f, cst=%f\n',PRN(prn), doppler_frequency(prn), CNR(prn), code_start_time(prn));
        end
    end
    
%     [in_sig, fid, fileNo] = load_gps_data('ece584_2sec.bin',0,1);
%     SV_offset_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%     E_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%     L_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%     current_CA_code = sign(cacodegn(ephem(1,1))-0.5);
%     for time_offset = 0:T_RES:TP-T_RES
%         [SV_offset_CA_code(:,1 + round(time_offset/T_RES)) ...
%             E_CA_code(:,1 + round(time_offset/T_RES)) ...
%             L_CA_code(:,1 + round(time_offset/T_RES))] ...
%             = digitize_ca(-time_offset,current_CA_code);
%     end
%     tic;
%     initial_acquisition(in_sig,current_CA_code);
%     acq_time=toc;
%     tic;
%     aided_acquisition(in_sig,ecef([65.116936,-147.4347125,0]),488500,0,ephem(1,1));
%     aided_time=toc;
%     disp('Aided Improvement:');
%     disp(sprintf('   Acquisition Time=%.3f, Aided Time=%.3f, %% improvement=%.3f',acq_time,aided_time,100*(acq_time-aided_time)/acq_time));
%     disp(sprintf('   Total Time=%.3f, Total Aided Time=%.3f',acq_time*32,aided_time*32));
%     disp(sprintf('   Reduced Aided Time=%.3f, Improvement=%.3f, %% improvement=%.3f',aided_time*12,32*acq_time-12*aided_time,100*(32*acq_time-12*aided_time)/(32*acq_time)));
%     
%     disp('Navigation error:');
%     sample=samples(1);
%     time=obs(sample,2);
%     pose=solveposod(ephem,pseudo_range(sample,:)',[0 0 0],time);
%     posa=solveposod(ephema,pseudo_range(sample,:)',[0 0 0],time);
%     disp(sprintf('   dx=%.3f, dy=%.3f, dz=%.3f, dcdr=%.3f',pose(2)-posa(2),pose(3)-posa(3),pose(4)-posa(4),pose(5)-posa(5)));
%     
%     disp('Statistics:');
%     disp(' Position Error:');
%     disp(sprintf('   mean=%.3f, std=%.3f',mean(ds(:,1)),std(ds(:,1))));
%     disp(sprintf('   dx: mean=%.3f, std=%.3f',mean(ds(:,2)),std(ds(:,2))));
%     disp(sprintf('   dy: mean=%.3f, std=%.3f',mean(ds(:,3)),std(ds(:,3))));
%     disp(sprintf('   dz: mean=%.3f, std=%.3f',mean(ds(:,4)),std(ds(:,4))));
%     disp(' Doppler:');
%     disp(sprintf('   mean=%.3f, std=%.3f',mean(ddopp),std(ddopp)));
end