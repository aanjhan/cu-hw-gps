function clear_track(prn);
    if(nargin==0)
        delete('PRN*_hist_*.mat');
        return;
    end
    
    for i=1:length(prn)
        delete(sprintf('PRN%d_hist_*.mat',prn(i)));
    end
end