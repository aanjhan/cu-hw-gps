function ecef=SatToEcef(positions)
%Convert satellite positions from their relative orbit
%coordinate frames to ECEF positions.
%
%Inputs:
%   positions - a matrix containing the X and Y positions
%               for each position, as well as each satellite
%               orbit's argument of perigee (degrees), inclination
%               (degrees), and right ascension (degrees).
%               [ SV Xorb Yorb w i l ;
%                        ...
%                 SV Xorb Yorb w i l ]
%
%Outputs:
%   ecef - a matrix containing the X, Y, and Z positions
%          of each satellite in ECEF coordinates.
%          [ SV Xecef Yecef Zecef ;
%                    ...
%            SV Xecef Yecef Zecef ]
satellites = size(positions,1);
if (satellites == 0)
    return;
end

ecef=zeros(satellites,4);

%Set SVs.
ecef(:,1)=positions(:,1);

%Compute ECEF coordiantes for each satellite.
%ECEF=Rz(-w)Rx(-i)Rz(-l)ORB
for i=1:satellites
    ecef(i,2:4)=RotZ(RotX(RotZ([positions(i,2:3) 0],-positions(i,4)),-positions(i,5)),-positions(i,6));
end
end