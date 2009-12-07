%tested on 9/2006
% pseudoCa.m	(actual file name: pseudoCa.m)
%
% < DOES NOT INCLUDE IONOSPHERIC CORRECTIONS >
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
%
% output: 'pseudo-range' matrix which rows contain a GPS time
%		(seconds), and then pairs of SV id numbers with corresponding
%		corrected pseudo-ranges (meters)
%						[ GPStime svID pr svID pr ... ;
%						  GPStime svID pr svID pr ... ;
%											...
%						  GPStime svID pr svID pr ... ]
%
% < DOES NOT INCLUDE IONOSPHERIC CORRECTIONS >
%
function pseudo_range = pseudocalc(ephem,pseudo)
    % define physical constants
    constant;
    % clear variable 'pseudo_range'
    pseudo_range = [ ];
    % determine time samples
    GPStime = pseudo(:,1);
    % determine number of samples taken
    samples = size(pseudo,1);
    % determine number of satellites being used
    satellites = size(ephem,1);
    % get clock correction parameters from 'ephem'
    refTime = ephem(:,24);
    af0 = ephem(:,20);
    af1 = ephem(:,21);
    af2 = ephem(:,22);
    tgd = ephem(:,23);
    t_oe = ephem(:,4);
    tgd = ephem(:,23);
    ecc = ephem(:,5);
    sqrta = ephem(:,6);
    M0 = ephem(:,8);
    dn = ephem(:,11);
    
    % create 'pseudo_range' by correcting pseudo-ranges of each raw
    % pseudo-range measurement for each time sample
    for t = 1:samples
        % determine pseudo-range corrections due to satellite clock
        % corrections calculate time offset from satellite reference
        % time
        timeOffset = GPStime(t)-refTime;
        % calculate clock corrections 'cc'
        cc = af0+af1.*timeOffset+af2.*timeOffset.^2-tgd;
        % calculate change in raw pseudo-range due to clock
        % corrections
        clockCorr = c.*cc;
        
        %determine the relativistic correction using the GPS-IS-200
        %specification from pp 88-89
        timeOffset = GPStime(t) - t_oe; %differently defined offset for finding E
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
        
        % calculate total pseudo-range correction
        pseudoCorr = clockCorr + rel_corr*c;
%         pseudoCorr = clockCorr;
        
        % apply corrections to pseudo-range measurements and add
        % samples into 'pseudo_range' structure
        sample = GPStime(t);
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