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
    
    samples=[obs(1,1) obs(end,1)];
    for s=1:1%length(samples)
        sample=samples(s);
        time=obs(sample,2);
        
        %Find ephemeris and almanac satellites.
%        subplot(1,length(samples),s);
        satpose=findsat(ephem,time);
        [satposa,satvela]=findsat(ephema,time);
        satposa(:,1)=satposa(:,1)+100;
        elaz=elevazim([satpose;satposa],ecef([65.116936,-147.4347125,0]));
%        plotsat(elaz);
    
        %Positional errors.
        disp(sprintf('Sample %d (%d s)',sample,time));
        disp(' Satellite position error:');
        for i=1:size(satpose,1)
            disp(sprintf('   PRN %d diff=%.3f',satpose(i,1),sqrt(sum((satpose(i,3:5)-satposa(i,3:5)).^2))));
        end
        disp(' Navigation error:');
        pose=solveposod(ephem,pseudo_range(sample,:)',[0 0 0],time);
        posa=solveposod(ephema,pseudo_range(sample,:)',[0 0 0],time);
        disp(sprintf('   dx=%.3f, dy=%.3f, dz=%.3f, dcdr=%.3f',pose(2)-posa(2),pose(3)-posa(3),pose(4)-posa(4),pose(5)-posa(5)));
        disp(sprintf('   error=%.3f',sqrt(sum((pose(2:4)-posa(2:4)).^2))));
        
        [in_sig, fid, fileNo] = load_gps_data('ece584_60sec.bin',0,1);
        [PRN, doppler_frequency, code_start_time, CNR]=aided_acquisition(in_sig,ecef([65.116936,-147.4347125,0]),488500);
        for prn=1:length(PRN)
            %if the signal was not found, quit this satellite
            if(CNR(prn)<CNO_MIN || code_start_time(prn) < 0)  
                fprintf('Warning: Initial Acquisition failed: PRN %02d not found in data set\n',PRN(prn))
                fprintf('Doppler Frequency: %d   Code Start Time: %f    CNR: %f\n',doppler_frequency(prn), code_start_time(prn), CNR(prn));
            %otherwise track the satellite
            else 
                fprintf('PRN %d Found: Doppler Frequency: %d, CNR = %04.2f\n',PRN(prn), doppler_frequency(prn), CNR(prn));
            end
        end
%         
%         %Doppler shift.
%         obsLatLong=[65.116936,-147.4347125,0];
%         obsPos=ecef(obsLatLong);
%         vObs=OmegaE*norm(obsPos)*cos(obsLatLong(1)*pi/180)*[-sin(obsLatLong(2)*pi/180) cos(obsLatLong(2)*pi/180) 0];
%         satPos=satposa(:,3:5);
%         satVel=satvela(:,2:4);
%         rho=sqrt(sum((satPos-ones(size(satPos,1),1)*obsPos).^2,2));
%         velpe=vObs;
%         rhohat=(satPos-ones(size(satPos,1),1)*obsPos)./(rho*ones(1,3));
%         dopp=zeros(size(satPos,1),1);
%         for s=1:size(satPos,1)
%             dopp(s)=f_L1*((-rhohat(s,:)*(satVel(s,:)-velpe)')/(c+rhohat(s,:)*(satVel(s,:)-velpe)'));
%         end
%         
%         doppler_frequency=zeros(size(satpose,1),1);
%         %load 1 sec. of data from file
%         [in_sig, fid, fileNo] = load_gps_data('ece584_60sec.bin',0,1);
%         for s=1:size(satpose,1)
%             %generate CA code for the particular satellite, and then again for each time_offset,
%             %and again at each time offset for each early and late CA code
%             %initialize arrays for speed
%             SV_offset_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%             E_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%             L_CA_code = zeros(ONE_MSEC_SAM,TP/T_RES);
%             %and obtain the CA code for this particular satellite
%             current_CA_code = sign(cacodegn(ephem(s,1))-0.5);
%             %loop through all possible offsets to gen. CA_Code w/ offset
%             for time_offset = 0:T_RES:TP-T_RES       
%                 [SV_offset_CA_code(:,1 + round(time_offset/T_RES)) ...
%                     E_CA_code(:,1 + round(time_offset/T_RES)) ...
%                     L_CA_code(:,1 + round(time_offset/T_RES))] ...
%                     = digitize_ca(-time_offset,current_CA_code);
%             end
%             doppler_frequency(s) = initial_acquisition(in_sig,current_CA_code);
%         end
%         
%         disp(' Projected Dopplers:');
%         for i=1:size(satpose,1)
%             disp(sprintf('   PRN %d Doppler=%.3f Hz, truth=%.3f Hz, error=%.3f (%.2f%%)',...
%                 satpose(i,1),dopp(i),doppler_frequency(i),...
%                 doppler_frequency(i)-dopp(i),100*(doppler_frequency(i)-dopp(i))/doppler_frequency(i)));
%         end
    end
end