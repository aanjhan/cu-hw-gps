function test_almanac()
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
    for s=1:length(samples)
        sample=samples(s);
        time=obs(sample,2);
        
        subplot(1,length(samples),s);
        satpose=findsat(ephem,time);
        satposa=findsat(ephema,time);
        satposa(:,1)=satposa(:,1)+100;
        elaz=elevazim([satpose;satposa],ecef([65.116936,-147.4347125,0]));
        plotsat(elaz);
    
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
    end
end