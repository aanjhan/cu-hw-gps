% SEQUENCE FOR MAKING .vwf FILES:
% - Run log_gen(<any PRN #>,<length>,<doppler>,0)
% - Run twos_to_ones(<data>,3)
% - Run write_vwf(<data>,<Verilog subdirectory>,<filename>)

function write_vwf(signal,directory,filename)
    filename=sprintf('../../verilog/%s/%s.vwf',directory,filename);
    file=fopen(filename,'w');
    if(file<0)
        error('Unable to open file %s.',filename);
    end
    
    f_system=200e6;
    f_s=100e6;
    t_s=1/f_s;
    t_step=t_s*1e9;
    t_sys_step=1/f_system*1e9;
    start_cycles=8;
    start_time=start_cycles*t_sys_step;
    extra_cycles=200;
    data_end=start_time+length(signal)*t_step;
    end_time=data_end+extra_cycles*t_sys_step;
    
    fwrite(file,sprintf('/* End Time: %d */\n\n',end_time));

    %Write clk.
    fwrite(file,sprintf('TRANSITION_LIST("clk")\n'));
    fwrite(file,sprintf('{\n'));
    fwrite(file,sprintf('\tNODE\n'));
    fwrite(file,sprintf('\t{\n'));
    fwrite(file,sprintf('\t\tREPEAT = 1;\n'));
    fwrite(file,sprintf('\t\tNODE\n'));
    fwrite(file,sprintf('\t\t{\n'));
    fwrite(file,sprintf('\t\t\tREPEAT = %d;\n',round(end_time*1e-9*f_system)));
    fwrite(file,sprintf('\t\t\tLEVEL 0 FOR %.1f;\n',1/f_system/2*1e9));
    fwrite(file,sprintf('\t\t\tLEVEL 1 FOR %.1f;\n',1/f_system/2*1e9));
    fwrite(file,sprintf('\t\t}\n'));
    fwrite(file,sprintf('\t}\n'));
    fwrite(file,sprintf('}\n'));
    fwrite(file,sprintf('\n'));

    %Write clk_sample.
    fwrite(file,sprintf('TRANSITION_LIST("clk_sample")\n'));
    fwrite(file,sprintf('{\n'));
    fwrite(file,sprintf('\tNODE\n'));
    fwrite(file,sprintf('\t{\n'));
    fwrite(file,sprintf('\t\tREPEAT = 1;\n'));
    fwrite(file,sprintf('\t\tNODE\n'));
    fwrite(file,sprintf('\t\t{\n'));
    fwrite(file,sprintf('\t\t\tREPEAT = %d;\n',round(start_time*1e-9*f_s)));
    fwrite(file,sprintf('\t\t\tLEVEL 0 FOR %.1f;\n',1/f_s*1e9));
    fwrite(file,sprintf('\t\t}\n'));
    fwrite(file,sprintf('\t\tNODE\n'));
    fwrite(file,sprintf('\t\t{\n'));
    fwrite(file,sprintf('\t\t\tREPEAT = %d;\n',round((data_end-start_time)*1e-9*f_s)));
    fwrite(file,sprintf('\t\t\tLEVEL 1 FOR %.1f;\n',1/f_s/2*1e9));
    fwrite(file,sprintf('\t\t\tLEVEL 0 FOR %.1f;\n',1/f_s/2*1e9));
    fwrite(file,sprintf('\t\t}\n'));
    fwrite(file,sprintf('\t}\n'));
    fwrite(file,sprintf('}\n'));
    fwrite(file,sprintf('\n'));

    %Write sample_valid.
    fwrite(file,sprintf('TRANSITION_LIST("sample_valid")\n'));
    fwrite(file,sprintf('{\n'));
    fwrite(file,sprintf('\tNODE\n'));
    fwrite(file,sprintf('\t{\n'));
    fwrite(file,sprintf('\t\tREPEAT = 1;\n'));
    fwrite(file,sprintf('\t\tLEVEL 0 FOR %.1f;\n',start_time));
    fwrite(file,sprintf('\t\tLEVEL 1 FOR %.1f;\n',data_end-start_time));
    fwrite(file,sprintf('\t\tLEVEL 0 FOR %.1f;\n',end_time-data_end));
    fwrite(file,sprintf('\t}\n'));
    fwrite(file,sprintf('}\n'));
    fwrite(file,sprintf('\n'));
    
    %Add time bars at each code interval.
    %Note: Time bars are described in ps.
    for t=start_time:floor(t_step*16800):data_end
        fwrite(file,sprintf('TIME_BAR\n'));
        fwrite(file,sprintf('{\n'));
        fwrite(file,sprintf('\tTIME = %d;\n',t*1e3));
        if(t==start_time)
            fwrite(file,sprintf('\tMASTER = TRUE;\n'));
        else
            fwrite(file,sprintf('\tMASTER = FALSE;\n'));
        end
        fwrite(file,sprintf('}\n'));
        fwrite(file,sprintf('\n'));
    end
    
    %Write data.
    for i=2:-1:0
        bit=bitand(bitshift(signal,-i),1);
        
        remaining=(end_time-start_time-length(bit)*t_step)/t_step;
        if(remaining>0)
            bit=[bit;zeros(remaining,1)];
            bit(end+1)=1;
        end
        
        fwrite(file,sprintf('TRANSITION_LIST("data[%d]")\n',i));
        fwrite(file,sprintf('{\n'));
        fwrite(file,sprintf('\tNODE\n'));
        fwrite(file,sprintf('\t{\n'));
        fwrite(file,sprintf('\t\tREPEAT = 1;\n'));
        len=start_time;
        value=0;
        for j=1:length(bit)
            if(bit(j)~=value)
                fwrite(file,sprintf('\t\tLEVEL %d FOR %.1f;\n',value,len));
                value=bit(j);
                len=0;
            end
            len=len+t_step;
        end
        fwrite(file,sprintf('\t}\n'));
        fwrite(file,sprintf('}\n'));
        fwrite(file,sprintf('\n'));
    end
    
    fclose(file);
    fclose all;
end