function device=serial_open(device_name)
if(ispc)
    fclose all;
    device=serial(device_name,'baudrate',115200,'timeout',0.1);
    fopen(device);
else
    device=serial_open_unix(device_name);
end
return;