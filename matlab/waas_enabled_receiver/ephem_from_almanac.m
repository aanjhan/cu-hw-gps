function [ephem,healthy]=ephem_from_almanac(almanac)
    ephem=zeros(size(almanac,1),24);
    
    healthy=zeros(size(almanac,1),1);
    healthy(find(almanac(:,2)==0))=1;
    
    
    ephem(:,1)=almanac(:,1);%SV ID.
    ephem(:,2)=0;%Reference week number.
    ephem(:,3)=0;%GPS reference time (s).
    ephem(:,4)=almanac(:,4);%Reference time of week - time of epoch (s).
    ephem(:,5)=almanac(:,3);%Eccentricity.
    ephem(:,6)=almanac(:,7);%Square root of the semi-major axis (m^1/2).
    ephem(:,7)=almanac(:,9);%Argument of perigee (rad).
    ephem(:,8)=almanac(:,10);%Mean anomaly at reference time (rad).
    ephem(:,9)=almanac(:,8);%Right ascension at reference time (rad).
    ephem(:,10)=almanac(:,6);%Rate of right ascension (rad/s).
    ephem(:,11)=0;%Mean motion difference (rad/s).
    ephem(:,12)=almanac(:,5);%Inclination angle at reference time (rad).
    ephem(:,13)=0;%Inclination angle rate (rad/s).
    ephem(:,14)=0;%Latitude cosine harmonic correction (rad).
    ephem(:,15)=0;%Latitude sine harmonic correction (rad).
    ephem(:,16)=0;%Orbit radius cosine harmonic correction (m).
    ephem(:,17)=0;%Orbit radius sine harmonic correction (m).
    ephem(:,18)=0;%Inclination cosine harmonic correction (rad).
    ephem(:,19)=0;%Inclination sine harmonic correction (rad).
    ephem(:,20)=almanac(:,11);%Af0 clock correction (s).
    ephem(:,21)=almanac(:,12);%Af1 clock correction (s/s).
    ephem(:,22)=0;%Af2 clock correction (s/s^2).
    ephem(:,23)=0;%Tgd clock correction (s).
    ephem(:,24)=0;%Toc time of clock ephemeris reference time (s).
end