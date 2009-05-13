function val=TwosToVal(data)
    data=mod(data+4,8);
    twos=[7 6 5 0 1 2 3];
    val=twos(data);
end