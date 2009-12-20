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
function el_az = elevazim(satLoc,obsLoc);
% define constants
constant;
% determine number of satellites; exit if zero satellites
satellites = size(satLoc,1);
if (satellites == 0)
    return;
end

% compute unit vector from observation station to satellite position
r=zeros(satellites,3);
for i=1:satellites
    r(i,:) = satLoc(i,3:5)-obsLoc;
    r(i,:) = r(i,:)/norm(r(i,:));
end

% compute the observation latitude and longitude
obsLoc = latlong(obsLoc);
latOBS = obsLoc(1) * degrad;		% radians
longOBS = obsLoc(2) * degrad;		% radians
% compute the unit vectors rotated into VEN from observation station to satellite position 
north = [-cos(longOBS)*sin(latOBS), -sin(longOBS)*sin(latOBS), cos(latOBS)];
east =  [-sin(longOBS), cos(longOBS), 0];
vertical = [cos(longOBS)*cos(latOBS), sin(longOBS)*cos(latOBS), sin(latOBS)];

elevation=zeros(satellites,1);
azimuth=zeros(satellites,1);
for i=1:satellites
    % compute elevation
    elevation(i) = (pi/2-acos(vertical*r(i,:)'))/degrad;
    % compute azimuth
    azimuth(i) = atan2((east*r(i,:)'),(north*r(i,:)'));
end
%check for negative angles
idx = find(azimuth < 0);
azimuth(idx) = azimuth(idx) + 2 * pi;
azimuth = azimuth ./ degrad;				% degrees
% return 'el_az'
el_az = [ satLoc(:,1) satLoc(:,2) elevation azimuth ];
return;