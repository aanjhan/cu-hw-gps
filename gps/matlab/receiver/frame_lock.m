function  [sfindex, data, lock] = frame_lock(data)
%function  [sfidnum, sfindex, data, lock] = FRAME_LOCK(data)
%bwo1: changed 1/3/07 to not calculate sfidnum
%
% This function will take as input:
%
% Input               Description
% data                an arbitrary length of bit synchronized data (1s & 0s)
%
% The function will then search the data stream for preambles of 3
% consecutive subrames (each separated by 300 bits).  If this search proves
% unsuccessful it may be because of the polarity ambiguity from bit
% magnitude definition from phase information.  In this case we then search
% for 3 consecutive inverted preambles.  If this search is successful we
% then invert the data stream to the correct polarity.  If both searches
% are unsuccessful it will be indicated by the match (and lock) variable.
%
% The outputs are:
%
% Output              Description
% sfidnum             the subframe number of the first found subframe
% sfindex             the index in data of the beginning of the first found subframe
% data                the data stream (which may have been inverted if necessary)
% lock                an indicator of successful frame lock (0 unsuccessful, 1 successful)
%
%AUTHORS:  Alex Cerruti (apc20@cornell.edu), Mike Muccio
%(mtm15@cornell.edu), Brady O'Hanlon (bwo1@cornell.edu)
%Copyright 2009, Cornell University, Electrical and Computer Engineering,
%Ithaca, NY 14853

preamble = [1;0;0;0;1;0;1;1];
datalength = length(data);

i=1;
lock=0;

%search for 2 consecutive preambles
%keep going until a match is found
while((lock==0)&&(i<datalength-346))
    %if we found a preamble
    if(preamble==data(i:i+length(preamble)-1))
        %check after 300 bits to see if the next preamble is found
        if(preamble==data(300+(i:i+length(preamble)-1)))
            %now check for correctly incremented z-count
            if(i>1)
                %if D30==1, must invert data from this word
                if(data(i+29)==1)
                    zcount1 = mat2int(~data(i+(30:46)));
                else %non-inverted
                    zcount1 = mat2int(data(i+(30:46)));
                end
                if(data(i+329)==1)
                    zcount2 = mat2int(~data(i+(30:46)+300));
                else
                    zcount2 = mat2int(data(i+(30:46)+300));
                end
                if(zcount2==zcount1+1)
                    %if so, then jump out of this while loop & the function
                    lock=1;
                    break;
                end
            end
        end
    end
    i = i+1;
end

%if first search unsuccessful search for 2 consecutive inverted preambles
if(lock==0)

    %invert preamble
    preamble = ~preamble;
    i=1;

    %search
    %keep going until a match is found
    while((lock==0)&&(i<datalength-346))
        %if we found a preamble
        if(preamble==data(i:i+length(preamble)-1))
            %check after 300 bits to see if the next preamble is found
            if(preamble==data(300+(i:i+length(preamble)-1)))
                %now check for properly incremented Z-count
                if(i>1)
                    %must invert data if D30*==1
                    if(data(i+29)==1)
                        zcount1 = mat2int(~data(i+(30:46)));
                    else %non-inverted
                        zcount1 = mat2int(data(i+(30:46)));
                    end
                    if(data(i+329)==1)
                        zcount2 = mat2int(~data(i+(30:46)+300));
                    else
                        zcount2 = mat2int(data(i+(30:46)+300));
                    end
                    if(zcount2==zcount1+1)
                        %if so, then jump out of this while loop & the function
                        lock=1;
                        break;
                    end
                end
            end
        end
        i = i+1;
    end

end

%determine the subframe starting index
sfindex = i;

return;
