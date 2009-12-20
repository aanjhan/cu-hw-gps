%tested 9/2006
% solvepos.m	(actual file name: solvepos.m)
%
% this function calculates the position of the observation station
%
% input: 'ephem' matrix which rows contain orbital ephemerides for
%		a given satellite
%					< see formatData.m for description >
%			'pseudoR' vector which contains pseudo-ranges (meters) for
%		the satellites being used in the navigational solution
%						[ pr pr pr pr ]
%			'guess' vector containing an initial position guess in
%		ECEF coordinates
%			'gpsTime' variable which contains the GPS time a
%		navigational solution will be found for
%
% output: 'posOBS' matrix which contains a GPS time (seconds), ECEF
%		coordiates of the navigational solution (meters) and the
%		receiver clock offset at that GPS time (seconds)
%						[ GPStime ECEFx ECEFy ECEFz recCO ]
%
function [posOBS,iters] = solvepos(ephem,pseudoR,guess,gpsTime)
    % define physical constants
    constant;
    satellites=size(ephem,1);
    % initialize real range to satellites
    range=zeros(satellites,1);
    iters=0;
    % solve for position iteratively until solution is within an
    % acceptable error
    stop = 0;
    while (stop == 0)
        iters=iters+1;
        % create guess matrix
        guessmatrix = ones(satellites,1)*guess;
        % calculate difference between time of reception and
        % transmission in	order to shift satellites back to where
        % they where at transmission
        % satellite movement correction
        transT = range./c;
        % calculate iterated range based on GPS time sample
        satXYZ = findsat(ephem,gpsTime-transT);
        satX = satXYZ(:,3);
        satY = satXYZ(:,4);
        satZ = satXYZ(:,5);
        % correction due to rotation of the Earth
        delX = OmegaE.*transT.*satY;
        delY = -OmegaE.*transT.*satX;
        satX = satX+delX;
        satY = satY+delY;
        satXYZ = [satX, satY, satZ];
        % calculate satellite ranges 'range' from guess to satellites
        delXYZ =  satXYZ-guessmatrix;
        range = sqrt(sum(delXYZ.^2,2));
        %  form the vector 'l' and the matrix 'A'
        %PseudoR created from pseudocalc script. Includes
        %satellite clock corrections.
        l = pseudoR-range;

        %Example of A entry: d/dx(range(1))=-(Xsat-Xguess)/Range(guess)
        %range(j)=> of jth sat, delXYZ(j,i)=>jth sat, i is X,Y,orZ
        A=[-delXYZ(:,1)./range -delXYZ(:,2)./range -delXYZ(:,3)./range -ones(satellites,1)];

        % solve for  'deltaPos' which is contains dx, dy, dz, and  dt
        deltaPOS = A\l;
        %we'll find out pretty quickly, since it won't converge.
        % calculate 'obsPos' by adding 'deltaPos' to the current guess
        obsPos = guess+deltaPOS(1:3)';
        %receiver_clockoff=deltaPOS(4) %make sure this is same each iter.
        % check to see if the initial guess and the computed result is
        % "close enough"; if it is, then stop the iteration by setting the
        % 'stop' flag to 1; else, set the new initial guess equal to the
        % last computed value, and iterate again
        if (all(abs(obsPos(1:3) - guess) < 1e-6) || iters > 10) %we might want this better than -6?
            stop = 1;
        end
        guess = obsPos(1:3);
    end
    obsPos = [obsPos(1:3) deltaPOS(4)/c]; %be sure to include the Rec clock offset
    % create the output matrix 'posOBS' and return
    posOBS(1) = gpsTime;
    posOBS(2:5) = obsPos;
    return;