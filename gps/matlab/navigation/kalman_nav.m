function [X,posLatLong,Xraw]=kalman_nav(dataSelect,removeIon)

if(nargin==0)
    dataSelect=0;
    removeIon=0;
elseif(nargin~=2)
    removeIon=0;
end

if(dataSelect==1)
    position=ecef([42,-76,0]);
    static=1;
    
    %Data set measurement noise.
    sigmaP=5;
    sigmaD=5;
    
    %Data set process noise.
    PhisVel=0.01;
    PhisCdr=0.01;
    PhisNCO=0.01;
    PhisBias=10;

    ephemData=load('ephem.asc');
    SVs=ephemData(:,1)';
    
    obs=load('obs.asc');
    [ephem pseudorange_L1]=formatdata(ephemData,obs,SVs); %#ok<NODEF>
    pseudorange_L1=pseudocalc(ephem,pseudorange_L1);%Remove satellite clock offsets.
    pseudorange_L1=pseudorange_L1(:,1:2:end);
    
    obsdopp=load('obsdopp.asc');
    [ephem doppler_L1]=formatdata(ephemData,obsdopp,SVs); %#ok<NODEF>
    doppler_L1=doppler_L1(:,1:2:end);
    
    clear obs;
    clear obsdopp;
    clear ephemData;
    
    pseudorange_L1=pseudorange_L1(2:end,:);
    doppler_L1=doppler_L1(2:end,:);
elseif(dataSelect==2)
    position=ecef([65.1186,-147.4329,523.6649]);
    static=1;
    
    %Data set measurement noise.
    sigmaP=100;
    sigmaD=5;
    
    %Data set process noise.
    PhisVel=0.01;
    PhisCdr=0.01;
    PhisNCO=0.01;
    PhisBias=10;

    ephemData=load('ephem_alaska.asc');
    SVs=ephemData(:,1)';
    
    obs=load('obs_alaska.asc');
    [ephem pseudorange_L1]=formatdata(ephemData,obs,SVs); %#ok<NODEF>
    pseudorange_L1=pseudocalc(ephem,pseudorange_L1);%Remove satellite clock offsets.
    pseudorange_L1=pseudorange_L1(:,1:2:end);
    
    obsdopp=load('obsdopp_alaska.asc');
    [ephem doppler_L1]=formatdata(ephemData,obsdopp,SVs); %#ok<NODEF>
    doppler_L1=doppler_L1(:,1:2:end);
    
    clear obs;
    clear obsdopp;
    clear ephemData;
    
    pseudorange_L1=pseudorange_L1(2:end,:);
    doppler_L1=doppler_L1(2:end,:);
else
    error('Invalid data set');
end
    
    constant;
    measurements=size(pseudorange_L1,1);
%     measurements=1000;
    maxSatellites=size(pseudorange_L1,2)-1;

    %Initial measurement positions.
    SVs=find(pseudorange_L1(1,2:end)~=0);
    satellites=length(SVs);
    
    %Initial position from pseudorange navigation solution.
    Xraw=zeros(measurements,5);
    Xraw(1,:)=solvepos(ephem(SVs,:),pseudorange_L1(1,SVs+1)',position,pseudorange_L1(1,1));
    
    %Initial state vector.
    %X(1)=x, X(2)=dx/dt
    %X(3)=y, X(4)=dy/dt
    %X(5)=z, X(6)=dz/dt
    %X(7)=cdr, X(8)=dcdr/dt
    %X(9)=NCO offset
    %X(9+j)=biasj
    X=zeros(measurements,9+maxSatellites);
    numStates=size(X,2);
    X(1,[1 3 5])=Xraw(1,2:4);
    X(1,7)=Xraw(1,5)*c;
    X(1,9)=-800;%FIXME How to initialize NCO offset?
    P=30^2*eye(numStates);
    P(7,7)=20^2;
    P(8,8)=50^2;
    P(9,9)=1e2^2;%FIXME How to initialize NCO offset?
    P(10:end,10:end)=30^2*eye(maxSatellites);
    
    posLatLong=zeros(measurements,3);
    posLatLong(1,:)=latlong(X(1,[1 3 5]));
    Vars=zeros(measurements,numStates);
    Vars(1,:)=diag(P);
    for i=2:measurements
        Ts=pseudorange_L1(i,1)-pseudorange_L1(i-1,1);

        %Fundamental Matrix
        Phi=zeros(numStates);
        %X position/velocity.
        Phi(1:2,1:2)=[ 1, Ts;
                       0, 1 ;];
        %Y position/velocity.
        Phi(3:4,3:4)=[ 1, Ts;
                       0, 1 ;];
        %Z position/velocity.
        Phi(5:6,5:6)=[ 1, Ts;
                       0, 1 ;];
        %Receiver clock offset/drift rate.
        Phi(7:8,7:8)=[ 1, Ts;
                       0, 1 ;];
        %NCO offset.
        Phi(9,9)=1;
        %Satellite bias.
        Phi(10:end,10:end)=eye(maxSatellites);

        %Process Noise Matrix
        Q=zeros(numStates);
        %X position/velocity process noise.
        Q(1:2,1:2)=PhisVel*[ Ts^3/3 , Ts^2/2;
                             Ts^2/2 , Ts    ;];
        %Y position/velocity process noise.
        Q(3:4,3:4)=PhisVel*[ Ts^3/3 , Ts^2/2;
                             Ts^2/2 , Ts    ;];
        %Z position/velocity process noise.
        Q(5:6,5:6)=PhisVel*[ Ts^3/3 , Ts^2/2;
                             Ts^2/2 , Ts    ;];
        %Receiver clock offset process noise.
        Q(7:8,7:8)=PhisCdr*[ Ts^3/3 , Ts^2/2;
                             Ts^2/2 , Ts    ;];
        %NCO offset process noise.
        Q(9,9)=PhisNCO*Ts;
        %Satellite bias process noise.
        Q(10:end,10:end)=PhisBias*Ts*eye(maxSatellites);
   
        %Project state forward.
        Xp=Phi*X(i-1,:)';
        posp=Xp([1 3 5]);
        velp=Xp([2 4 6]);
        cdrp=Xp(7);
        cdrdotp=Xp(8);
        ncop=Xp(9);
        biasp=Xp(10:end);
        
        %Compute new satellite list.
        SVs=find(pseudorange_L1(i,2:end)~=0);
        
        %Calculate range projection.
        [rho,satPos,satVel]=rangecal(ephem(SVs,:),pseudorange_L1(i,1),posp);
        rho=rho(1,3:2:end)';
        satPos=[satPos(1:3:end)' satPos(2:3:end)' satPos(3:3:end)'];
        satVel=[satVel(1:3:end)' satVel(2:3:end)' satVel(3:3:end)'];
        
        %Remove satellites below the horizon.
        elaz=elevazim([ephem(SVs,1) pseudorange_L1(i,1)*ones(length(SVs),1) satPos],posp');
        setSVs=find(elaz(:,3)<=0);
        SVs(setSVs)=[];
        PRNs=ephem(SVs,1);
        satellites=length(SVs);
        rho(setSVs)=[];
        satPos(setSVs,:)=[];
        satVel(setSVs,:)=[];
        
        %Calculate measurement covariance.
        R=[diag(sigmaP^2./sin(elaz(:,3)*pi/180)) zeros(satellites);
           zeros(satellites) sigmaD^2*eye(satellites)];
%         R=[sigmaP^2*eye(satellites) zeros(satellites);
%            zeros(satellites) sigmaD^2*eye(satellites)];
        
        %Calculate doppler shift projection, adding velocity
        %component due to the rotation of the Earth.
        k=ones(satellites,1)*posp'-satPos;
        khat=k./(rho*ones(1,3));
        obsLatLong=latlong(posp');
        vObs=OmegaE*norm(posp)*cos(obsLatLong(1)*pi/180)*[-sin(obsLatLong(2)*pi/180) cos(obsLatLong(2)*pi/180) 0];
        
        refTime=ephem(SVs,24);
        af1=ephem(SVs,21);
        af2=ephem(SVs,22);
        delsdot=-(af1+2.*af2.*(pseudorange_L1(i,1).*ones(satellites,1)-refTime));
        f0=f_L1./(1+delsdot);
        velpe=velp+vObs';
        pdiff=satPos-ones(satellites,1)*posp';
        vdiff=satVel-ones(satellites,1)*velpe';
        rhohat=(satPos-ones(satellites,1)*posp')./(rho*ones(1,3));
        dopp=zeros(satellites,1);
        for s=1:satellites
            dopp(s)=f0(s)*((cdrdotp-rhohat(s,:)*(satVel(s,:)'-velpe))/(c+rhohat(s,:)*(satVel(s,:)'-velpe))-delsdot(s));
        end
        dopp=dopp+ncop;
        
        %Recompute measurement matrix.
        %PL1j=PL1j-cdj=rhoj-cdr+biasj
        dPL1dx=-(satPos(:,1)-posp(1))./rho;
        dPL1dxdot=zeros(satellites,1);
        dPL1dy=-(satPos(:,2)-posp(2))./rho;
        dPL1dydot=zeros(satellites,1);
        dPL1dz=-(satPos(:,3)-posp(3))./rho;
        dPL1dzdot=zeros(satellites,1);
        dPL1dcdr=-ones(satellites,1);
        dPL1dcdrdot=zeros(satellites,1);
        dPL1dnco=zeros(satellites,1);
        dPL1dbias=zeros(satellites,maxSatellites);
%         for s=1:satellites; dPL1dbias(s,SVs(s))=1; end;
        
        %Derivative of Doppler shift with respect to pseudorange rate.
        %dpr=rhohat*(vsat-vrec)
        dpr=dot(rhohat,vdiff,2);
        dDddpr=f0.*(-cdrdotp-c)./(c+dpr).^2;
        
        %Calculate derivate of Doppler with respect to x from derivative of
        %pseudorange rate with respect to x.
        ddprdx=zeros(satellites,3);
        ddprdx(:,1)=-1./rho+pdiff(:,1)./rho.^3.*pdiff(:,1);
        ddprdx(:,2)=pdiff(:,1)./rho.^3.*pdiff(:,2);
        ddprdx(:,3)=pdiff(:,1)./rho.^3.*pdiff(:,3);
        dDdx=(dot(ddprdx,vdiff,2)+rhohat(:,2)*OmegaE).*dDddpr;
        
        %Calculate derivate of Doppler with respect to y from derivative of
        %pseudorange rate with respect to y.
        ddprdy=zeros(satellites,3);
        ddprdy(:,1)=pdiff(:,2)./rho.^3.*pdiff(:,1);
        ddprdy(:,2)=-1./rho+pdiff(:,2)./rho.^3.*pdiff(:,2);
        ddprdy(:,3)=pdiff(:,2)./rho.^3.*pdiff(:,3);
        dDdy=(dot(ddprdy,vdiff,2)-rhohat(:,1)*OmegaE).*dDddpr;
        
        %Calculate derivate of Doppler with respect to z from derivative of
        %pseudorange rate with respect to z.
        ddprdz=zeros(satellites,3);
        ddprdz(:,1)=pdiff(:,3)./rho.^3.*pdiff(:,1);
        ddprdz(:,2)=pdiff(:,3)./rho.^3.*pdiff(:,2);
        ddprdz(:,3)=-1./rho+pdiff(:,3)./rho.^3.*pdiff(:,3);
        dDdz=dot(ddprdz,vdiff,2).*dDddpr;
        
        %Calculate derivate of Doppler with respect to velocity from
        %derivative of pseudorange rate with respect to velocity.
        dDdxdot=-rhohat(:, 1).*dDddpr;
        dDdydot=-rhohat(:, 2).*dDddpr;
        dDdzdot=-rhohat(:, 3).*dDddpr;
        
        dDdcdr=zeros(satellites,1);
        dDdcdrdot=f0./(c+dpr);
        dDdnco=ones(satellites,1);
        dDdbias=zeros(satellites,maxSatellites);
        
%         H=[dPL1dx dPL1dxdot dPL1dy dPL1dydot dPL1dz dPL1dzdot dPL1dcdr dPL1dcdrdot dPL1dnco dPL1dbias;
%            zeros(satellites,1) dDdxdot zeros(satellites,1) dDdydot zeros(satellites,1) dDdzdot dDdcdr dDdcdrdot dDdnco dDdbias;];
        H=[dPL1dx dPL1dxdot dPL1dy dPL1dydot dPL1dz dPL1dzdot dPL1dcdr dPL1dcdrdot dPL1dnco dPL1dbias;
           dDdx dDdxdot dDdy dDdydot dDdz dDdzdot dDdcdr dDdcdrdot dDdnco dDdbias;];
        
%         x0=Xp;
%         dopptest0=DopplerFromState(SVs,ephem,rho,satPos,satVel,pseudorange_L1(i,1),x0);
%         doppdiff=doppler_L1(i,SVs+1)'-dopptest0;
%         
%         diff=zeros(satellites,numStates-maxSatellites);
%         for j=1:numStates-maxSatellites
%             dxp=zeros(numStates,1);
%             dxp(j)=1e-1;
%             x1=Xp+dxp;
%             fd_rho=sqrt(sum((satPos-ones(satellites,1)*x1([1 3 5])').^2,2));
%             dopptest1=DopplerFromState(SVs,ephem,fd_rho,satPos,satVel,pseudorange_L1(i,1),x1);
%             dD=(dopptest1-dopptest0)./dxp(j);
%             diff(:,j)=(H(satellites+1:end,j)-dD)./dD;
%         end
%         
%         dopptest2=f0.*((Xp(8)-(dpr+1e-2))./(c+dpr+1e-2)-delsdot);
%         diffdpr=dDddpr-(dopptest2-dopptest0)./1e-2;
        
        %Compute Kalman gains from Riccati equations.
        M=Phi*P*Phi'+Q;
        S=H*M*H'+R;
        K=M*H'*inv(S);
        P=M-K*S*K';
        
        Vars(i,:)=diag(P);
        
        if(removeIon)
            if(dataSelect==1 && removeIon==2)
%                 TEC=(pseudorange_L1(i,SVs+1)'-pseudorange_L2(i,SVs+1)')./(40.3/f_L1^2-40.3/f_L2^2);
%                 correctedPR=pseudorange_L1(i,SVs+1)'-40.3/f_L1^2*TEC;
                ionCorr=(pseudorange_L1(i,SVs+1)'-pseudorange_L2(i,SVs+1)');
                correctedPR=pseudorange_L1(i,SVs+1)'-ionCorr;
            else
                ionCorr=IonCorrection(ephem(SVs,:),pseudorange_L1(i,1),ion,posp');
                correctedPR=pseudorange_L1(i,SVs+1)'-ionCorr;
            end
        else
            correctedPR=pseudorange_L1(i,SVs+1)';
        end
        
        %Update state from measurement residuals.
        measurement=[correctedPR;
                     doppler_L1(i,SVs+1)';];
        proj=[(rho-cdrp+biasp(SVs));
              dopp];
        res=measurement-proj;
        X(i,:)=Xp+K*(res);
        
        posLatLong(i,:)=latlong(X(i,[1 3 5]));
        if(satellites~=0)
            Xraw(i,:)=solvepos(ephem(SVs,:),pseudorange_L1(i,SVs+1)',Xraw(i-1,2:4),pseudorange_L1(i,1));
        else
            Xraw(i,:)=Xraw(i-1,:);
        end
    end
    
if(static)
    %True position (Ithaca).
    ithaca=ones(measurements,1)*position;
    
    errorCorr=sqrt(sum((X(:,[1 3 5])-ithaca).^2,2));
    errorRaw=sqrt(sum((Xraw(:,2:4)-ithaca).^2,2));
    
    posLatLong=[posLatLong errorCorr];
    
    t=pseudorange_L1(1:measurements,1);
    rows=3+ceil(satellites/2);
    figure(1);
    subplot(rows,2,1:2);
    i=[1 3 5];
    plot(t,errorCorr,'b',...
        t,errorRaw,'r',...
        t,sqrt(sum(Vars(:,i),2)),'g--',t,-sqrt(sum(Vars(:,i),2)),'g--');
    title({'Position Error';
        sprintf('Filtered: mean=%.2f m, std dev=%.2f m',mean(errorCorr),std(errorCorr));
        sprintf('Raw: mean=%.2f m, std dev=%.2f m',mean(errorRaw),std(errorRaw))});
    ylabel('Error (m)');
    xlabel('GPS Time (s)');
    
    subplot(rows,2,3);
    i=[2 4 6];
    plot(t,sqrt(sum(X(:,i).^2,2)),'b',...
        t,sqrt(sum(Vars(:,i),2)),'g--',t,-sqrt(sum(Vars(:,i),2)),'g--');
    title('Velocity Error');
    ylabel('Error (m/s)');
    xlabel('GPS Time (s)');
    
    subplot(rows,2,4);
    plot(t,X(:,7)./c,'b');
    title('Receiver Clock Offset');
    ylabel('Error (s)');
    xlabel('GPS Time (s)');
    
    subplot(rows,2,5);
    plot(t,X(:,8)./c,'b');
    title('Receiver Clock Offset Drift');
    ylabel('Drift (s/s)');
    xlabel('GPS Time (s)');
    
    subplot(rows,2,6);
    plot(t,X(:,9),'b');
    title('NCO Offset');
    ylabel('Offset (Hz)');
    xlabel('GPS Time (s)');
    
    for sat=1:satellites
        subplot(rows,2,6+sat);
        i=9+sat;
        plot(t,X(:,i),'b');
        title(sprintf('Satellite %d Bias',ephem(sat,1)));
        ylabel('Bias (m)');
        xlabel('GPS Time (s)');
    end
else
    figure(1);
    clf;
    hold on;
    plot3(X(:,1),X(:,3),X(:,5));
    plot3(Xraw(:,2),Xraw(:,3),Xraw(:,4),'r');
    hold off;
    title('ECEF Position Plot');
    axis equal;
end
return;

function dopp=DopplerFromState(SVs,ephem,rho,satPos,satVel,time,X)
    constant;
    satellites=length(SVs);
    
    posp=X([1 3 5]);
    velp=X([2 4 6]);
    obsLatLong=latlong(posp');
    vObs=OmegaE*norm(posp)*cos(obsLatLong(1)*pi/180)*[-sin(obsLatLong(2)*pi/180) cos(obsLatLong(2)*pi/180) 0];
    velpe=velp+vObs';
    
    refTime=ephem(SVs,24);
    af1=ephem(SVs,21);
    af2=ephem(SVs,22);
    delsdot=-(af1+2.*af2.*(time.*ones(satellites,1)-refTime));
    f0=f_L1./(1+delsdot);
    
    rhohat=(satPos-ones(satellites,1)*posp')./(rho*ones(1,3));
    dopp=zeros(satellites,1);
    for s=1:satellites
        dopp(s)=f0(s)*((X(8)-rhohat(s,:)*(satVel(s,:)'-velpe))/(c+rhohat(s,:)*(satVel(s,:)'-velpe))-delsdot(s));
    end
return;