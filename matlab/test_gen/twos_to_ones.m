function val=twos_to_ones(data,quantization)
    max_value=2^(quantization-1)-1;
    table=-max_value:max_value;
    negative=table<0;
    table=abs(table);
    table=bitxor(table,2^(quantization-1)*negative);
    
    data=mod(data+(max_value+1),2*(max_value+1));
    val=table(data)';
end