% checked 8/2006
% elevazim.m	(actual file name: elevazim.m)
%
% this GPS utility calculates the elevation and azimuth from a
% reference position specified in ECEF coordinates (e.g. antenna
% location) to another position specified in ECEF coordinates
% (e.g. satellite location)
%
% input: 'satLoc' matrix which rows contain an SV id number, a GPS
%		time (seconds), and the ECEF coordinates (meters) of the 
%		satellite location
%						[ svID GSPtime ECEFx ECEFy ECEFz ;
%						  svID GPStime ECEFx ECEFy ECEFz ;
%											...
%						  svID GPStime ECEFx ECEFy ECEFz ]
%	 		'obsLoc' vector which contains the ECEF coordinates
%		(meters) of a reference position which elevation and azimuth
%		will be calculated from
%						[ ECEFx ECEFy ECEFz ]
%
% output: 'el-az' matrix which rows contain the an SV id number, a
%		GPS time (seconds), and the elevation and azimuth look angles
%		(degrees) to the satellite
%						[ svID GSPtime elevation azimuth ;
%						  svID GSPtime elevation azimuth ;
%											...
%		  				  svID GSPtime elevation azimuth ]
%
function el_az = elevazim(satLoc,obsLoc)
% define constants
	constant;
% define satellite locations in ECEF coordinates
	satX = satLoc(:,3);	% meters
	satY = satLoc(:,4);	% meters
	satZ = satLoc(:,5);	% meters
% define observation location in ECEF coordinates
	obsX = obsLoc(1);		% meters
	obsY = obsLoc(2);		% meters
	obsZ = obsLoc(3);		% meters
% compute unit vector from observation station to satellite position
	r = sqrt((satX - obsX).^2 + (satY - obsY).^2 + ...
		(satZ - obsZ).^2);	
	dx = (satX - obsX) ./ r;
	dy = (satY - obsY) ./ r;
	dz = (satZ - obsZ) ./ r;
% compute the observation latitude and longitude
	obsLoc = latlong(obsLoc);
   latOBS = obsLoc(1) * degrad;		% radians
   longOBS = obsLoc(2) * degrad;		% radians
% compute the rotated unit vectors in VEN from observation station to satellite position 
	north = dz .* cos(latOBS) - sin(latOBS) .* ...
		(dx .* cos(longOBS) + dy .* sin(longOBS));
	east = dy .* cos(longOBS) - dx .* sin(longOBS);
	vertical = cos(latOBS) .* (dx .* cos(longOBS) + ...
		dy .* sin(longOBS)) + dz .* sin(latOBS);
% compute elevation
	elevation = (pi / 2 - acos(vertical)) ./ degrad;    % degrees
% compute azimuth; check for negative angles
	azimuth = atan2(east,north);				% radians
	idx = find(azimuth < 0);
	azimuth(idx) = azimuth(idx) + 2 * pi;
	azimuth = azimuth ./ degrad;				% degrees
% return 'el_az'
	el_az = [ satLoc(:,1) satLoc(:,2) elevation azimuth ]; 
	return;
    