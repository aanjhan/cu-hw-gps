%tested 8/31/01
% printnav.m	(acutal file name: printnav.m)
%
% this function prints out the navigational solution in ECEF 
% coordinates and latitude-longitude-altitude coordinates
%
% input: 'posOBS' matrix which contains a GPS time (seconds), ECEF
%		coordiates of the navigational solution (meters) and the 
%		receiver clock offset at that GPS time (seconds)
%						[ GPS time ECEFx ECEFy ECEFz recCO ]
%
function [ ] = printnav(posOBS)
% get the navigational solution
	gpsTime = posOBS(1);
	obsECEFx = posOBS(2) / 1000;		% kilometers
	obsECEFy = posOBS(3) / 1000; 		% kilometers
	obsECEFz = posOBS(4) / 1000;		% kilometers
   dT = posOBS(5);
   posOBS = latlong(posOBS(2:4));
	obsLat = posOBS(1);
	obsLong = posOBS(2);
	obsAlt = posOBS(3);
% display the navigation solution 
	fprintf('\nNavigation Solution :');
	fprintf('\n*********************');
	fprintf('\nGPS Time :			%11.3f  (seconds)',gpsTime);
	fprintf('\nLatitude  :			%+.7f  (degrees)',obsLat);
	fprintf('\nLongitude  :			%+.7f  (degrees)',obsLong);
	fprintf('\nAltitude  :			%+.2f  (meters)',obsAlt);
	fprintf('\nClock Offset  :			%+.7f  (seconds)',dT);
	fprintf('\nECEF [X Y Z] Coordinates :		%+.3f  %+.3f  %+.3f  (kilometers)',obsECEFx, obsECEFy, obsECEFz);
	fprintf('\n\n');
	return;