%tested  9/2006
% findsat.m	(actual file name: findsat.m)
%
%	< INCLUDES CORRECTIONS >
%
% this GPS function computes satellite positions given the orbital
% ephemerides for at given times
%
% input: 'ephem' matrix which rows contain orbital ephemerides for
%		a given satellite
%					< see formatData.m for description >
%	 		't' vector conatins the GPS times each satellite position
%		will be calculated at; if all satellite positions are being
%		calculated at the same GPS time, 't' can be a scalar with
%		that GPS time; if only one satellite is specified in 'ephem'
%		and 't' contains a vector of times, then the satellite
%		position is found at multiple times
%
% output: 'satLoc' matrix which rows contain an SV id number, a GPS
%		time (seconds), and the ECEF coordinates (meters) of the
%		satellite location
%						[ svID GPStime ECEFx ECEFy ECEFz ;
%		  				  svID GPStime ECEFx ECEFy ECEFz ;
%											...
%						  svID GPStime ECEFx EFECy ECEFz ]
%
%	< INCLUDES CORRECTIONS >
%
function [satLoc,satVel,orb] = findsat(ephem,t)
% define physical constants
	constant;
% determine number of satellites; exit if zero satellites
	satellites = size(ephem,1);
	if (satellites == 0)
		return;
	end
% define orbital parameters
	t0 = ephem(:,4);			% ephemeris reference time (seconds)
	ecc = ephem(:,5);			% eccentricity (unitless)
	sqrta = ephem(:,6);		% square root of semi-major axis (meters1/2)
	omega0 = ephem(:,7);		% argument of perigee (radians)
	M0 = ephem(:,8);			% mean anomaly at reference time (radians)
	l0 = ephem(:,9);			% right ascension at reference (radians)
	omegaDot = ephem(:,10);	% rate of right acension (radians/second)
	dn = ephem(:,11);			% mean motion difference (radians/second)
	i0 = ephem(:,12); 		% inclination angle at reference time (radians)
	iDot = ephem(:,13); 		% inclination angle rate (radians/second)
	cuc = ephem(:,14);		% latitude cosine harmonic correction (radians)
	cus = ephem(:,15);		% latitude sine harmonic correction (radians)
	crc = ephem(:,16);		% orbit radius cosine harmonic correction (meters)
	crs = ephem(:,17);		% orbit radius sine harmonic correction (meters)
	cic = ephem(:,18);		% inclination cosine harmonic correction (radians)
	cis = ephem(:,19);		% inclination sine harmonic correction (radians)
    toc = ephem(:,24);      % time of clock, ephemeris (seconds)
   % if time parameter 't' is a vector and only one satellite; find 
   % that satellite position over an array of times
	if ((size(t,1) ~= 1) & (satellites == 1))
		sat_ephem = ephem;
		for samples = 2:size(t,1)
			ephem = [ ephem ; sat_ephem ];
		end
	end
% if time parameter 't' is a single value, create time vector
	if (size(t,1) == 1)
		t = t .* ones(satellites,1);
	end
% define time of position request and delta t from epoch; correct 
% for possible week crossovers; 604800 seconds in a GPS week
	dt = t - t0;
	idx = find(dt > 302400);	% if into the next week
	dt(idx) = dt(idx) - 604800;
	idx = find(dt < -302400);	% if into the previous week
	dt(idx) = dt(idx) + 604800;
% calculate mean anomaly with corrections
	Mcorr = dn.*dt; 
	M = M0 + (sqrt(muearth) * (sqrta).^(-3)) .* dt + Mcorr; 
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
% calculate true anomoly from eccentric anomoly
	sinnu = sqrt(1 - ecc.^2) .* sin(E) ./ (1 - ecc .* cos(E));
	cosnu = (cos(E) - ecc) ./ (1 - ecc .* cos(E));
	nu = atan2(sinnu,cosnu);
% calculate the argument of latitude and the argument of perigee
% iteratively.
	omega = omega0;
   for i = 1:5
		u = omega+nu;
		cos2u = cos(2.*u);
        sin2u = sin(2.*u);
		omegaCorr = cuc.*cos2u+cus.*sin2u;
		omega = omega0 + omegaCorr;
   end
% calculate longitude of ascending node with correction
	lcorr = omegaDot.*dt;
    l = l0 - OmegaE .* t + lcorr;
% calculate orbital radius with correction
	rCorr = crc.*cos2u+crs.*sin2u;
	r = (sqrta.^2) .* (1 - ecc .* cos(E)) + rCorr;
% calculate inclination with correction
	iCorr = iDot.*dt+cic.*cos2u+cis.*sin2u;
	i = i0 + iCorr;
% find position in orbital plane
	u = omega + nu;
	xp = r .* cos(u);
	yp = r .* sin(u);
% find satellite position in ECEF coordinates
	ECEFx = (xp .* cos(l)) - (yp .* cos(i) .* sin(l));
	ECEFy = (xp .* sin(l)) + (yp .* cos(i) .* cos(l));
	ECEFz = (yp .* sin(i));
    %Calculate satellite velocity.
    a=sqrta.^2;
    n=sqrt(muearth./a.^3);
    rdotX=a.^2.*n./r.*-sin(E);
    rdotY=a.^2.*n./r.*sqrt(1-ecc.^2).*cos(E);
    rdot=[rdotX rdotY];
    satVel=SatToEcef([ephem(:,1) rdot omega.*180./pi i.*180./pi l.*180./pi]);
    orb=[i ecc a l omega E];
% return satellite locations
	satLoc = [ ephem(:,1) t ECEFx ECEFy ECEFz ];
	return;