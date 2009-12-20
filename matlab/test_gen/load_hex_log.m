function i_q=load_hex_log(file)
    fid = fopen(file,'r');
    line = fgetl(fid);
    i_q=[];
    while line~=-1
        parts = regexp(tline,',','split');
        i_q=[i_q; hex2dec(parts(1)) hex2dec(parts(2))];
        line = fgetl(fid);
    end
    return;