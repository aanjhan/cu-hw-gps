%tested 10/29/03
% pseudocalc.m	(actual file name: pseudoca.m)
%
%	< USES IONOSPHERIC CORRECTIONS >
%
% this function calculates the pseudo-ranges based on raw
% pseudo-ranges with clock corrections applied
%
% input: 'ephem' matrix which rows contain orbital ephemerides for
%		a given satellite; including satellite time correction terms
%					< see formatData.m for description >
%			'pseudo' matrix which rows contain pseudo-range samples
%		for a given time
%					< see formatData.m for description >
%					< in this case, psuedo = obs structure >
%			'ionParam' matrix of the eight coefficients used to correct
%		for ionospheric delay
%							[ alpha0 beta0
%							  alpha1 beta1
%							  alpha2 beta2
%					  		  alpha3 beta3 ]
%
% output: 'pseudo-range' matrix which rows contain a GPS time
%		(seconds), and then pairs of SV id numbers with corresponding
%		corrected pseudo-ranges (meters)
%						[ GPStime svID pr svID pr ... ;
%						  GPStime svID pr svID pr ... ;
%											...
%						  GPStime svID pr svID pr ... ]
%
%	< USES IONOSPHERIC CORRECTIONS >
%
function pseudo_range = pseudocaion(ephem,pseudo,ionParam,obsLoc, ion_Corr_on)
% define physical constants
constant;
% clear variable 'pseudo_range'
pseudo_range = [ ];
% determine time samples
gpsTime = pseudo(:,1);
% determine number of samples taken
samples = size(pseudo,1);
% determine number of satellites being used
satellites = size(ephem,1);

% determine user location in radians
lat = obsLoc(1) * degrad;
long = obsLoc(2) * degrad;
% get clock correction parameters from 'ephem'
t_oe = ephem(:,4);
t_oc = ephem(:,24);
af0 = ephem(:,20);
af1 = ephem(:,21);
af2 = ephem(:,22);
tgd = ephem(:,23);
ecc = ephem(:,5);
sqrta = ephem(:,6);
M0 = ephem(:,8);
dn = ephem(:,11);
% create 'pseudo_range' by correcting pseudo-ranges of each raw
% pseudo-range measurement for each time sample
for t = 1:samples
    % determine pseudo-range corrections due to satellite clock corrections
    % calculate time offset from satellite reference time
    timeOffset = gpsTime(t) - t_oc;
    if(abs(timeOffset) > 302400)
        timeOffset = timeOffset-sign(timeOffset).*604800;
    end
    % calculate clock corrections 'cc'
    cc = af0 + af1 .* timeOffset + af2 .* (timeOffset .^ 2) - tgd;
    % calculate change in raw pseudo-range due to clock corrections
    clockCorr = cc * c;

    %determine the relativistic correction using the GPS-IS-200
    %specification from pp 88-89
    timeOffset = gpsTime(t) - t_oe; %differently defined offset for finding E
    if(abs(timeOffset) > 302400)
        timeOffset = timeOffset-sign(timeOffset).*604800;
    end
    %Mcorr = dn*t_oe;
    M = M0 + ((sqrt(muearth) .* sqrta.^(-3))+dn).* timeOffset;
    % compute the eccentric anomaly from mean anomaly using
    % Newton-Raphson method to solve for 'E' in:
    %		f(E) = M - E + ecc * sin(E) = 0
    E = M;
    for i = 1:10
        f = M - E + ecc .* sin(E);
        dfdE = - 1 + ecc .* cos(E);
        dE = - f ./ dfdE;
        E = E + dE;
    end
    rel_corr = -4.442807633e-10.*ecc.*sqrta.*sin(E);
    %total correction thus far is relativistic+satellite clock
    pseudoCorr = clockCorr + rel_corr*c;
    % determine pseudo-range corrections due to ionospheric signal delay
    % find satellites' elevation and azimuth at GPS time
    if(ion_Corr_on)
        % determine ionspheric parameters 'alpha' and 'beta'
        alpha = ionParam(:,1);
        beta = ionParam(:,2);
        
        satLoc = findsat(ephem,gpsTime(t));
        el_az = elevazim(satLoc,obsLoc);
        El = el_az(:,3) * degrad;
        A = el_az(:,4) * degrad;
        % calculate earth's central angle between user position and
        % projected ionospheric point (assume a mean ionospheric
        % height of 350,000 meters and a spherical Earth of radius
        % 6,371,000 meters)
        psi = 0.1356*((El + 0.346).^(-1)) - 0.0691;
        % calculate geodetic latitude of the earth projection ionospheric
        % intersection
        lati = lat + psi .* cos(A);
        idx = find(lati > 1.3090);
        nidx = size(idx,1);
        if nidx > 0
            lati(idx) = 1.3090 * ones(nidx,1);
        end
        idx = find(lati < -1.3090);
        nidx = size(idx,1);
        if nidx > 0
            lati(idx) = -1.3090 * ones(nidx,1);
        end
        % calculate geodetic longitude of the earth projection
        % ionospheric intersection
        longi = long + psi .* sin(A) ./ cos(lati);
        % calculate solar time
        solarTime = 1.3751e+04 .* longi + gpsTime(t);
        idx = find(solarTime > 84600);
        nidx = size(idx,1);
        while (nidx > 0)
            solarTime(idx) = solarTime(idx) - 84600;
            idx = find(solarTime > 84600);
            nidx = size(idx,1);
        end
        idx = find(solarTime < 0);
        nidx = size(idx,1);
        while (nidx > 0)
            solarTime(idx) = solarTime(idx) + 84600;
            idx = find(solarTime < 0);
            nidx = size(idx,1);
        end
        % calculate geomagnetic latitude of the earth projection of the
        % ionospheric intersection point
        latm = lati + 2.02e-1 .* cos(longi - 5.08);
        % create geomagnetic latitude matrix.  The alpha and beta parameters
        % assume that latm is measured in semi-circles rather than in radians.
        latmdum = latm*(1/pi);
        latM = [ ones(size(latmdum,1),1),...
            latmdum, latmdum.^2, latmdum.^3 ];
        % calculate period
        period = latM * beta;
        % calculate phase
        x = 2 * pi * (solarTime - 50400) ./  period;
        % calculate amplitude
        amplitude = latM * alpha;
        idx = find(amplitude < 0);
        nidx = size(idx,1);
        if nidx > 0
            amplitude(idx) = zeros(nidx,1);
        end
        % calculate the slant factor (again assume a mean ionospheric
        % height of 350,000 meters and a spherical Earth of radius
        % 6,371,000 meters)
        slantFactor = 1.0 + 5.16e-01 * ((1.6755 - El).^3);
        % calculate iononspheric delay
        ionDelay = slantFactor .* 5.0e-09;
        idx = find(abs(x) < (0.5*pi));
        nidx = size(idx,1);
        if nidx > 0
            ionDelay(idx) = slantFactor(idx) .* ...
                (5.0e-09 + amplitude(idx) .* cos(x(idx)));
        end
        % calculate change in raw pseudo-range due to clock corrections
        ionCorr = ionDelay .* c;
        %subtract from current pseudoCorr
        pseudoCorr = pseudoCorr - ionCorr;
    end

    % apply corrections to pseudo-range measurements and add samples
    % into 'pseudo_range' structure
    sample = gpsTime(t);
    for i = 1:satellites
        pseudoR = pseudo(t,2 * i + 1);
        if (pseudoR ~= 0)
            corrPseudoR = pseudoR + pseudoCorr(i);
        else
            corrPseudoR = 0;
        end
        sample = [ sample ephem(i,1) corrPseudoR ];
    end
    pseudo_range = [ pseudo_range; sample ];
end
% return corrected pseudo-ranges
return;