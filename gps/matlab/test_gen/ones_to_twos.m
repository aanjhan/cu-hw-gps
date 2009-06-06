function val=ones_to_twos(data,quantization)
    max_value=2^(quantization-1)-1;
    table=[0:max_value 0:-1:-max_value];
    val=table(data+1)';
end