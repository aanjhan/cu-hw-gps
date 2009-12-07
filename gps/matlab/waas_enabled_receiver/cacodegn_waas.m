function codehist = cacodegn_waas(PRNNo)
%
%  Copyright (c) 2006 Mark L. Psiaki.  All rights reserved.
%  Modified 5/2006 Paul M. Kintner and Alex Cerruti
%
%  This function computes the 1023-length CA code for the GPS satellite
%  with PRN number PRNNo.
%
%  Generate the G1 and G2 sequences.
%  initialize the shift registers
G1hist = ones(1,10);
G2hist = ones(1,10);
codehist = zeros(1023,1); %this is the output
waas_flag = (PRNNo > 32); %indicate whether a WAAS C/A code is being generated
                          %since it requires a different encoder
% WAAS-specific quantities
G2_delay = 0;  %G2 delay in chips
G2_init = 0;   %Initial G2 setting (octal)

%pick appropriate taps for particular PRN
if PRNNo < 1 || (PRNNo > 32 && PRNNo < 120) || PRNNo > 138
    return;
end

switch PRNNo
    case 1
        g2tap1 = 2; g2tap2 = 6;
    case 2
        g2tap1 = 3; g2tap2 = 7;
    case 3
        g2tap1 = 4; g2tap2 = 8;
    case 4
        g2tap1 = 5; g2tap2 = 9;
    case 5
        g2tap1 = 1; g2tap2 = 9;
    case 6
        g2tap1 = 2; g2tap2 = 10;
    case 7
        g2tap1 = 1; g2tap2 = 8;
    case 8
        g2tap1 = 2; g2tap2 = 9;
    case 9
        g2tap1 = 3; g2tap2 = 10;
    case 10
        g2tap1 = 2; g2tap2 = 3;
    case 11
        g2tap1 = 3; g2tap2 = 4;
    case 12
        g2tap1 = 5; g2tap2 = 6;
    case 13
        g2tap1 = 6; g2tap2 = 7;
    case 14
        g2tap1 = 7; g2tap2 = 8;
    case 15
        g2tap1 = 8; g2tap2 = 9;
    case 16
        g2tap1 = 9; g2tap2 = 10;
    case 17
        g2tap1 = 1; g2tap2 = 4;
    case 18
        g2tap1 = 2; g2tap2 = 5;
    case 19
        g2tap1 = 3; g2tap2 = 6;
    case 20
        g2tap1 = 4; g2tap2 = 7;
    case 21
        g2tap1 = 5; g2tap2 = 8;
    case 22
        g2tap1 = 6; g2tap2 = 9;
    case 23
        g2tap1 = 1; g2tap2 = 3;
    case 24
        g2tap1 = 4; g2tap2 = 6;
    case 25
        g2tap1 = 5; g2tap2 = 7;
    case 26
        g2tap1 = 6; g2tap2 = 8;
    case 27
        g2tap1 = 7; g2tap2 = 9;
    case 28
        g2tap1 = 8; g2tap2 = 10;
    case 29
        g2tap1 = 1; g2tap2 = 6;
    case 30
        g2tap1 = 2; g2tap2 = 7;
    case 31
        g2tap1 = 3; g2tap2 = 8;
    case 32
        g2tap1 = 4; g2tap2 = 9;
    case 120
        G2_delay = 145;
        G2_init = '1106';
    case 121
        G2_delay = 175;
        G2_init = '1241';
    case 122
        G2_delay = 52;
        G2_init = '0267';
    case 123
        G2_delay = 21;
        G2_init = '0232';
    case 124
        G2_delay = 237;
        G2_init = '1617';
    case 125
        G2_delay = 235;
        G2_init = '1076';
    case 126
        G2_delay = 886;
        G2_init = '1764';
    case 127
        G2_delay = 657;
        G2_init = '0717';
    case 128
        G2_delay = 634;
        G2_init = '1532';
    case 129
        G2_delay = 762;
        G2_init = '1250';
    case 130
        G2_delay = 355;
        G2_init = '0341';
    case 131
        G2_delay = 1012;
        G2_init = '0551';
    case 132
        G2_delay = 176;
        G2_init = '0520';
    case 133
        G2_delay = 603;
        G2_init = '1731';
    case 134
        G2_delay = 130;
        G2_init = '0706';
    case 135
        G2_delay = 359;
        G2_init = '1216';
    case 136
        G2_delay = 595;
        G2_init = '0740';
    case 137
        G2_delay = 68;
        G2_init = '1007';
    case 138
        G2_delay = 386;
        G2_init = '0450';
end

if (~ waas_flag)
    %  Load all rows and create C/A code
    for jj = 1:1023
        %create code for step jj first
        %note that modulo 2 addition is equivalent to xor
        codehist(jj) = mod(G1hist(10)+mod(G2hist(g2tap1)+G2hist(g2tap2),2),2);
        %  Create next row of G1
        G10 = [mod(sum(G1hist([3 10])),2) G1hist(1:9)];
        %  Insert next row of G1
        G1hist(:) = G10;
        %  Create next row of G2
        G20 = [mod(sum(G2hist([2 3 6 8 9 10])),2) G2hist(1:9)];
        %  Insert next row of G2
        G2hist(:) = G20;
    end
else
    %Create WAAS C/A code
    %--------------------

    %Initialize coder LSRs
    G1_coder = ones(1,10);
    G2_coder = zeros(1,10);
    G2_coder(1) = str2double(G2_init(1));
    octal_init = base2dec(G2_init(2:end),8);
    bin_init = dec2bin(octal_init,9);
    for i = 1:9
        G2_coder(10-i) = str2double(bin_init(i));
    end

    for jj = 1:1023
        %Create code for step jj first
        codehist(jj) = mod(G1_coder(10) + G2_coder(10),2);
        %Shift G1
        G1_coder = [mod(sum(G1_coder([3 10])),2) G1_coder(1:9)];
        %Shift G2
        G2_coder = [mod(sum(G2_coder([2 3 6 8 9 10])),2) G2_coder(1:9)];
    end
end


