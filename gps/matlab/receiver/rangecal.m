%tested 9/2006
% rangeCal.m	(actual file name: rangeCal.m)
%
% this function calculates the ranges from the observation station
% to selected satellites based on point-to-point distance
%
% input: 'ephem' matrix which rows contain orbital ephemerides for
%		a given satellite
%					< see formatData.m for description >
%			'pseudo' matrix which rows contain pseudo-range samples
%		for a given time
%					< see formatData.m for description >
%					< in this case, psuedo = obs structure >
%	 		'obsLoc' vector which contains the ECEF coordinates
%		(meters) of a reference position which ranges will be
%		calculated from
%						[ ECEFx ECEFy ECEFz ]
%
% output: 'range' matrix which rows contain a GPS time (seconds),
% 		and then pairs of SV id numbers with corresponding calculated 
% 		ranges (meters)
%						[ GPStime svID r svID r ... ;
%						  GPStime svID r svID r ... ;
%											...
%						  GPStime svID r svID r ... ]
%
function [range,satPos,satVel] = rangecalc(ephem,pseudo,obsLoc)
% define physical constants
	constant;
% clear variable 'range' 
	range = [ ];
% determine time samples
	GPStime = pseudo(:,1);
% detemine number of samples taken
	samples = size(GPStime,1);
% determine number of satellites ranges being calculated
	satellites = size(ephem,1);
% define observation station location in ECEF coordinates
	obsX = obsLoc(1);
	obsY = obsLoc(2);
	obsZ = obsLoc(3);
    
    satPos=zeros(samples,3*satellites);
    satVel=zeros(samples,3*satellites);
% create 'range' by calculating ranges from observation location to
% each satellite for each time sample
	for t = 1:samples
      % calculate initial range based on GPS time sample
		satXYZ = findsat(ephem,GPStime(t));
		satX = satXYZ(:,3);
		satY = satXYZ(:,4);
		satZ = satXYZ(:,5);
        r = sqrt((satX-obsX).^2+(satY-obsY).^2+(satZ-obsZ).^2);
      % use this range 'r' to recalculate satellite locations based
      % on transmission time
      %for i = 1:10
			% satellite movement correction
			transT = r./c;
			[satXYZ,vel] = findsat(ephem,GPStime(t)-transT);
			satX = satXYZ(:,3);
			satY = satXYZ(:,4);
			satZ = satXYZ(:,5);
			% correction due to rotation of the Earth
			delX = OmegaE.*transT.*satY;
			delY = -OmegaE.*transT.*satX;
			satX = satX+delX;
			satY = satY+delY;
            %correct satXYZ for rotation as well
            satXYZ(:, 3) = satX;
            satXYZ(:, 4) = satY;
            %correct velXYZ for rotation as well
            delVX = OmegaE.*transT.*vel(:, 3);
            delVY = -OmegaE.*transT.*vel(:, 2);
            vel(:, 2) = vel(:, 2) + delVX;
            vel(:, 3) = vel(:, 3) + delVY;
        for s=1:satellites
            satPos(t,1+(s-1)*3:3+(s-1)*3)=satXYZ(s,3:5);
            satVel(t,1+(s-1)*3:3+(s-1)*3)=vel(s,2:4);
        end
		% calculate actual satellite range from observation station
        r = sqrt((satX-obsX).^2+(satY-obsY).^2+(satZ-obsZ).^2);
      %end
		% add range calculations into 'range' structure
		sample = [ GPStime(t) ];
		for i = 1:satellites
			sample = [ sample ephem(i,1) r(i) ];
		end
		range = [ range; sample ];
	end
% return calculated ranges
	return;