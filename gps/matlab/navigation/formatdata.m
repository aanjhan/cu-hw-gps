% checked 8/2006
% formatdata.m	(actual file name: formatda.m)
%
% this utility transforms the data contained in 'ephemData' and 
% 'obsData' into more convenient structures: 'ephem' and 'obs'
%
% input: 'ephemData' matrix which rows contain satellite orbital
%		ephemerides
%	 		'obsData' matrix which rows contain a sample number. a GPS
%		time, and SV ids along with corresponding observables; either
%		pseudo-range or phase 
% 	 		'SV_ids' vector contains a list of SV ids which determine
%			which satellites data will be formated for
%	 
% output: 'ephem' matrix which rows contain satellite orbital 
%		ephemerides; the rows are sorted by SV id order based on the
%		input 'SV_ids'; the following is a description of the 'ephem'
%		fields :
%			ephem(:,1)	SV number
%			ephem(:,2)	ephemeris reference week number
%			ephem(:,3)	ephemeris GPS reference time (seconds)
%			ephem(:,4)	ephemeris reference time of week (seconds)
%			ephem(:,5)	eccentricity
%			ephem(:,6)	square root of semi-major axis (meters1/2) 
%			ephem(:,7)	argument of perigee (radians)
%			ephem(:,8)	mean anomaly at reference time (radians)
%			ephem(:,9)	right ascension at reference time (radians)
%			ephem(:,10)	rate of right ascension (radians/second) 
%			ephem(:,11)	mean motion difference (radians/second)
%			ephem(:,12)	inclination angle at reference time (radians)
%			ephem(:,13)	inclination angle rate (radians/second)
%			ephem(:,14)	latitude cosine harmonic correction (radians)
%			ephem(:,15)	latitude sine harmonic correction (radians)
%			ephem(:,16)	orbit radius cosine harmonic correction (meters)
%			ephem(:,17)	orbit radius sine harmonic correction (meters)
%			ephem(:,18)	inclination cosine correction (radians)
%			ephem(:,19)	inclination sine correction (radians)
%			ephem(:,20)	af0 clock correction (seconds)
%			ephem(:,21)	af1 clock correction (seconds/second)
%			ephem(:,22)	af2 clock correction (seconds/second2) 
%           ephem(:,23) tgd clock correction (seconds)
%           ephem(:,24) toc time of clock ephemeris reference time
%           (seconds)
% 	  		 'obs' martix which rows contain a GPS time and then SV ids
% 		followed by corresponding observables, either pseudo-range
% 		(meters) or phase (cycles); SV ids are sorted according to the
%		input 'SV_ids'; the following is a description of the 'obs'
%		fields :
%			obs(:,1)	GPS time for sample (seconds)
%			obs(:,2)	SV identification
%			obs(:,3)	raw observable corresponding to SV id
%			obs(:,4)	SV identification
%			obs(:,5)	raw observable corresponding to SV id
%	 						.
%							.
%							.
%
function [ ephem, obs ] = formatdata(ephemData,obsData,SV_ids)
% determine the number of satellites
	satellites = size(SV_ids,2);
% create 'ephem'
	for SV = 1:satellites
		r = find(ephemData(:,1) == SV_ids(SV));
		if (~isempty(r))
			ephem(SV,:) = ephemData(r,:);
		else
			ephem(SV,:) = zeros(1,24);
		end
	end
% remove all satellites with no ephemerides supplied
	idx = find(ephem(:,1) ~= 0);
	ephem = ephem(idx,:);
	SV_ids = SV_ids(idx);
	satellites = size(SV_ids,2);
% check if observable data has been supplied
	if (isempty(obsData))
		obs = [ ];
		return;
	end
% determine sample GPS times
	GPStime = obsData(:,2);
% determine number of samples
	samples = size(GPStime,1);
% create 'obs'
	SV_cols = [ ];   
	for i = 1:((size(obsData,2) - 1) / 2)
                SV_cols = [ SV_cols 2 * i + 1];
	end
	obs = zeros(samples,2 * satellites + 1);
	for t = 1:samples
		obs(t,1) = GPStime(t);
		for SV = 1:satellites
			c = find(obsData(t,SV_cols) == SV_ids(SV)) * 2;
			obs(t,2 * SV) = SV_ids(SV);
			if (~isempty(c))
				obs(t,2 * SV + 1) = obsData(t,c + 2);
			end
		end
	end
% return 'ephem', 'obs'
	return;