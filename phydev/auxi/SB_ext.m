% SB_ext.m - Extract FN and BSIC from SB. Note that the sb_seq is the bit
% order on Um, see 3GPP TS 44.004. sb_seq should be 25 bits long, see 3GPP
% TS 44.018.
%
% Copyright (C) 2013 Integrated System Laboratory ETHZ (SharperEDGE Team)
%
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
% Public License for more details.
%
% You should have received a copy of the GNU General Public License along
% with this program.  If not, see <http://www.gnu.org/licenses/>.

function [FN BSIC] = SB_ext(sb_seq)

% change the bit order
sb_seq = bit_order(sb_seq,'rx');

% extract BSIC
tmp = '';
offset = 0;
for i=1:6
    tmp(i) = num2str(sb_seq(i+offset));
end
BSIC = bin2dec(tmp);

% extract T1
tmp = '';
offset = 6;
for i=1:11
    tmp(i) = num2str(sb_seq(i+offset));
end
T1 = bin2dec(tmp);

% extract T2
tmp = '';
offset = 6+11;
for i=1:5
    tmp(i) = num2str(sb_seq(i+offset));
end
T2 = bin2dec(tmp);

% extract T3p
tmp = '';
offset = 6+11+5;
for i=1:3
    tmp(i) = num2str(sb_seq(i+offset));
end
T3p = bin2dec(tmp);

% compute T3 according to 3GPP TS 45.010
T3 = 10 * T3p + 1;


% compute FN according to 3GPP TS 45.010
FN = 51 * mod(T3-T2,26) + T3 + 51 * 26 * T1;

end