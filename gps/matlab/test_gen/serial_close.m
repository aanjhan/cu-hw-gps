function serial_close(device)
if(ispc)
    fclose(device);
else
    serial_close_unix(device);
end
return;