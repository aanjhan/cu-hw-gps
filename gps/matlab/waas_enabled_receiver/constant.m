% constant.m	(actual file name: constant.m)
%
% this GPS utility defines physical constants to be used in the
% GPS functions and utilities
%
% constants defined:
%	'mu' : G*Me, the "gravitational constant" for orbital motion 
%		about the Earth
%	'AA' : the semi-major axis of the reference ellipsoid (WGS-84)
%	'BB' : the semi-minor axis of the reference ellipsoid (WGS-84)
%	'esquare' : the square of the Earth's orbital eccentricity
%	'OmegaE' : the sidereal rotation rate of the Earth (WGS-84)
%	'c' : the speed of light (meters/second)
%	'degrad' : a constant used for converting degrees to radians
%	'leapSeconds' : the number of leap seconds currently for the
%		GPS system (seconds)
%	'f0' : the fundamental frequency for the GPS system (Hertz)
%	'f' : the L1 carrier frequency (Hertz)
%	'lambda' : the L1 carrier wave length (meters)
%
	muearth = 398600.5e9;			   % meters^3/second^2
	AA = 6378137.00000;					% meters
	BB = 6356752.31425;					% meters
	esquare=(AA^2 - BB^2) / AA^2;	
	OmegaE = 7.2921151467e-5;			% radians/second
	c = 299792458;							% meters/second 
	degrad = pi/180.0;
	leapSeconds = 14;						% seconds
	f0 = 10.23e6;							% Hertz
	f = 154 * f0;							% Hertz
	lambda = c / f;						% meters

    f_L1=154*f0;
    lambda_L1=c/f_L1;
    f_L2=120*f0;
    lambda_L2=c/f_L2;
    TECU=1e16;