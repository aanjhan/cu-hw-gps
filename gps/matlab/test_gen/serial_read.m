function data=serial_read(device,length,type)
if(nargin<3)
    type='uint8';
end

if(ispc)
    data=fread(device,length,type);
else
    data=serial_read_unix(device,length,type);
end
return;