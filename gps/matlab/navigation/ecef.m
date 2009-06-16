% checked 8/2006
% ecef.m	(actual file name: ecef.m)
%
% this GPS utility converts a WGS-84 latitude-longitude-altitude
% position into ECEF coordinates 
%
% input: 'location' vector which contains a position specified by
%		latitude (degrees), longitude (degrees), and altitude (meters)
%							[ latitude longitude altitude ]
% 
% output: 'ECEFxyz' vector which contains the same position 
%		specified by ECEF coordinates (meters)
%							[ ECEFx ECEFy ECEFz ]
%
function ECEFxyz = ecef(location)
% define physical constants
	constant;
% get lat-long-alt location to be converted to ECEF coordinates
	latdeg = location(1);	  
	londeg = location(2);	  
	alt = location(3);
% convert to radians		   
	lat = latdeg * degrad;		% latitude in radians
	lon = londeg * degrad;		% longitude in radians
% computes the ECEF coordinates 
	NN = AA^2 / sqrt((AA * cos(lat))^2 + (BB * sin(lat))^2);
	ECEFx = (NN + alt) * cos(lat) * cos(lon);		% meters
	ECEFy = (NN + alt) * cos(lat) * sin(lon);		% meters
	ECEFz = (NN * (BB / AA)^2 + alt) * sin(lat);	% meters
% return location in ECEF coordinates
	ECEFxyz = [ ECEFx ECEFy ECEFz ];
	return;