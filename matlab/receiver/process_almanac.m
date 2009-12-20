function process_almanac(svid)
    
%Load the bit stream.
load(sprintf('bit_cst_hist_%i',svid));

%Get bit lock and downsample the bit stream.
[bits, lock] = bit_lock(bit_overall_hist);

if(lock~=1)
    fprintf('Bit lock failed on SV %d, ignoring...',svid);
end

%Obtain frame lock.
[sfindex,data,frame_lock_ind] = frame_lock(bits);

if(frame_lock_ind~=1)
    fprintf('Frame lock failed on SV %d',svid);
    error('Unable to process data.');
end

%Extract and save the almanac.
almanac=extract_almanac(data,sfindex);
save almanac.asc almanac -ascii -double

end