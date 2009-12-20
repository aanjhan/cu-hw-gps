%tested 8/31/01
% calcdop.m		(actual file name: calcdop.m)
%
% this function calculates the dilution of precision of a 
% navigational solution based on the satellite geometry; given the
% parameters 'ephem' and 'gpsTime', calcdop can calculate satellite
% locations; the navigational solution 'posOBS' allows calcdop to 
% determine the 'A' matrix; it will return the output 'DOP' 
% formatted in the following way:
%
%	DOP(1)		geometrical dilution of precision
%	DOP(2)		positional dilution of precision
%	DOP(3)		time dilution of precision
%	DOP(4)		horizontal dilution of precision
%	DOP(5)		vertical dilution of precision
% 
function DOP = calcDOP(ephem,gpsTime,posOBS);
    constant;
% determine number of satellites
	numSats = size(ephem,1);
% format 'posOBS' to only have the observations ECEF coordinates
	posOBS = posOBS(2:4);
	obsX = posOBS(1);
	obsY = posOBS(2);
	obsZ = posOBS(3);
% calculate the 'A' matrix
	% calculate the satellite locations and ranges to them
	satLoc = findsat(ephem,gpsTime);
	satX = satLoc(:,3);
	satY = satLoc(:,4);
	satZ = satLoc(:,5);
	r = sqrt(sum(satLoc(:,3:5).^2,2));
	% format 'A' matrix
	A = [(obsX-satX)./r (obsY-satY)./r (obsZ-satZ)./r -ones(numSats,1)];
% calculate the cofactor matrix 'Q' which is the inverse of the normal
% equation matrix the 'Q' matrix has the following components
% [ qXX qXY qXZ qXt; qYX qYY qYZ qYt; qZX qZY qZZ qZt; qtX qtY qtZ qtt]
	Q = inv(A'*A);
% compute 'GDOP', 'PDOP', and 'TDOP' 
	GDOP = sqrt(trace(Q));
	PDOP = sqrt(trace(Q(1:3,1:3)));
	TDOP = sqrt(Q(4,4));
% to compute 'HDOP' and 'VDOP' need rotation matrix from ECEF to local frame
	% convert ECEF OBS into latitude-longitude coordinates
	posOBS = latlong(posOBS);
	phi = posOBS(1) * degrad; 			% latitude
	lambda = posOBS(2) * degrad;			% longitude
	% rotation matrix  'R'
	R = [-cos(lambda)*sin(phi) -sin(lambda)*sin(phi) cos(phi) 0;
         sin(lambda) cos(lambda) 0 0;
         cos(lambda)*cos(phi) cos(phi)*sin(lambda) sin(phi) 0;
         0 0 0 1];
	% calculate the local cofactor matrix
	Qlocal = R*Q*R';
	% calculate 'HDOP' and 'VDOP' 
	HDOP = sqrt(Qlocal(1,1)*Qlocal(2,2));
	VDOP = sqrt(Qlocal(3,3));
% return 'DOP'
DOP = [ GDOP PDOP TDOP HDOP VDOP ];
return;