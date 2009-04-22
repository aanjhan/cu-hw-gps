%tested on 8/31/01
% plotsat.m	(acutal file name: plotsat.m)
%
% this utility plots the calculated satellite positions or
% trajectories in an elevation-azimuth plot
%
% input: 'el-az' martix which rows contain an SV id number, a GPS
%		time (seconds), and the elevation-azimuth look angles
%		(degrees) to the satellite location; if positional plot is
%		desired the following condition must be met: the GPS time for
%		all satellites must be the same; if trajectory plot is desired
%		the following conditions must be met: the same number of
%		satellites must be included in each sample and within each
%		sample all GPS times must be the same
%							[ svID GPStime elevation azimuth ;
%		  					  svID GPStime elevation azimuth ;
%												...
%		  					  svID GPStime elevation azimuth ]
%
function [ ] = plotsatscint(el_az);
constant;
% convert all elevation and azimuth measurements into radians
SVs = unique(el_az(:,1));
el = el_az(:,3) .* degrad;
az = el_az(:,4) .* degrad;
% initialize polar - plotting area
theta = [0 pi/2 pi -pi/2];
rho = [1 1 1 1];
mmpolar(theta,rho,'w.','FontSize',16,'RLimit',[0 1],'RTickValue',[0 1/3 2/3 1],'RTickLabel',cellstr(['  '; '60'; '30'; ' 0']),'TTickLabel',cellstr(['270'; '240'; '210';'180'; '150'; '120'; ' 90'; ' 60'; ' 30'; ' 0 '; '330'; '300']))
hold on;

for s = 1:length(SVs)
    idx = find(el_az(:,1)==SVs(s));
    % plot trajectories (or positions) and label the last postion with
    % the satellite SV id.
    % loop through samples
    xyvec = nan(length(idx),4);
    % plot each satellite location for that sample
    
    count = 0;
    for i = 1:length(idx)
        if(i==1)
            curr_sign = sign(el(idx(i)));
        end
        prev_sign = curr_sign;
        curr_sign = sign(el(idx(i)));
        if(curr_sign ~= prev_sign)
            count = count+1;
        end
        % convert to plottable polar coordinates

        x = (pi/2-abs(el(idx(i))))/(pi/2).*cos(az(idx(i))-pi/2);
        y = -1*(pi/2-abs(el(idx(i))))/(pi/2).*sin(az(idx(i))-pi/2);
        xyvec(i,:) = [count, x, y, sign(el(idx(i)))];
    end

    num_lines = unique(xyvec(:,1));
    for j = 1:length(num_lines)
        idx = find(xyvec(:,1) == num_lines(j));
        [theta, rho] = cart2pol(xyvec(idx,2),xyvec(idx,3));
        if(xyvec(idx(1),4)==1)
            mmpolar(theta,rho,'b','LineWidth',2,'FontSize',16,'RLimit',[0 1],'RTickValue',[0 1/3 2/3 1],'RTickLabel',cellstr(['  '; '60'; '30'; ' 0']),'TTickLabel',cellstr(['270'; '240'; '210';'180'; '150'; '120'; ' 90'; ' 60'; ' 30'; ' 0 '; '330'; '300']))
        else
            mmpolar(theta,rho,'b:','LineWidth',2,'FontSize',16,'RLimit',[0 1],'RTickValue',[0 1/3 2/3 1],'RTickLabel',cellstr(['  '; '60'; '30'; ' 0']),'TTickLabel',cellstr(['270'; '240'; '210';'180'; '150'; '120'; ' 90'; ' 60'; ' 30'; ' 0 '; '330'; '300']))
        end
    end

    [t,r]= cart2pol(xyvec(end,2),xyvec(end,3));
    mmpolar(t,r,'k*','MarkerSize',10,'FontSize',16,'Font','Helvetica','RLimit',[0 1],'RTickValue',[0 1/3 2/3 1],'RTickLabel',cellstr(['  '; '60'; '30'; ' 0']),'TTickLabel',cellstr(['270'; '240'; '210';'180'; '150'; '120'; ' 90'; ' 60'; ' 30'; ' 0 '; '330'; '300']));
    text(xyvec(end,2),xyvec(end,3)+.07, int2str(SVs(s)));
end
return;