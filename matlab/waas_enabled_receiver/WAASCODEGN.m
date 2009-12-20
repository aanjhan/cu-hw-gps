function codehist = WAASCODEGN(PRNNo)
%
% bml. 
% 4.14.2003
%
% this code generates the WAAS C/A codes from PRN 120
% and PRN 122.  it was inspired by mark psiaki's 
% cacodegn.m  
%
%  Generate the G1 and G2 sequences.

   G1hist = zeros(1023,10);
   G2hist = zeros(1023,10);
   G1hist(1,:) = ones(1,10);
   %G2hist(1,:) = ones(1,10);
   
   if PRNNo == 120
     G2hist(1,:) = [0,1,1,0,0,0,1,0,0,1];
   elseif PRNNo == 122
     G2hist(1,:) = [1,1,1,0,1,1,0,1,0,0];
   elseif PRNNo ==138
     G2hist(1,:) = [0,0,0,1,0,1,0,0,1,0];
   else 
     disp('PRN No is invalid');
     return;
   end
    
   for jj = 2:1023
      jjm1 = jj - 1;
      G10 = xor(G1hist(jjm1,3),G1hist(jjm1,10));
      G1hist(jj,:) = [G10,G1hist(jjm1,1:9)];
      G20 = xor(G2hist(jjm1,2),xor(G2hist(jjm1,3),xor(G2hist(jjm1,6),...
          xor(G2hist(jjm1,8),xor(G2hist(jjm1,9),G2hist(jjm1,10))))));
      G2hist(jj,:) = [G20,G2hist(jjm1,1:9)];
   end

%
%  Now generate the output history.
%
  
   g2delay=G2hist(:,10); 
   codehist = xor(G1hist(:,10),g2delay);
   
% check it     
idx=10:-1:1;
n=norm(codehist(1:10)'-xor(ones(1,10),G2hist(1,idx)));


g2hist=G2hist(:,10);

%norm(G1hist(1:1023,10)-G1hist(1024:2046,10))
%norm(G2hist(1:1023,10)-G2hist(1024:2046,10))

%Change output type from logical to double
codehist = double(codehist);

return;




