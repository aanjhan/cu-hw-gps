% checked 8/2006
% latlong.m	(actual file name: latlong.m)
%
% this GPS utility converts a position specified in ECEF coordinates
% into WGS-84 latitude-longitude-altitude coordinates
%
% input: 'location' vector which contains a position specified by
%		ECEF coordinates (meters)
%							[ ECEFx ECEFy ECEFz
%                                    ...
%							  ECEFx ECEFy ECEFz ]
%
% output: 'ecoord' vector which contains the same position specified
%		by WGS-84 latitude (degrees), longitude (degrees), and 
%		altitude (meters)
%							[ latitude longitude altitude
%							               ...
%							  latitude longitude altitude ]
%
function ecoord = latlong(location);
% define physical constants
	constant;
    ecoord=zeros(size(location,1),3);
    for i=1:size(location,1)
        if(location(i,:)==0)
            ecoord(i,:)=[0 0 0];
            continue;
        end
        % get ECEF location to be converted to latitude-longitude-altitude
        % coordinates
        ECEFx = location(i,1);
        ECEFy = location(i,2);
        ECEFz = location(i,3);
        % compute the longitude which is an exact calculation
        long = atan2(ECEFy,ECEFx);
        % compute the latitude using iteration
        p = sqrt(ECEFx^2+ECEFy^2);
        % compute approximate latitude
        lat0 = atan(ECEFz/p*(1-esquare)^-1);
        stop = 0;
        while (stop == 0)
            N0 = AA^2/sqrt(AA^2*(cos(lat0))^2+BB^2*(sin(lat0))^2);
            altitude = p/cos(lat0)-N0;
            % calculate improved latitude
            term = N0/(N0+altitude);%FIXME Is this correct?
            lat = atan(ECEFz/p*(1-esquare*term)^-1);
            % check if result is close enough,
            if (abs(lat - lat0) < 1e-12)
                stop = 1;
            end
            lat0 = lat;
        end
        % convert the latitude and longitude to degrees
        latitude = lat/degrad;
        longitude = long/degrad;
        % return location in latitude-longitude-altitude coordinates
        ecoord(i,:) = [ latitude longitude altitude ];
    end
    return;