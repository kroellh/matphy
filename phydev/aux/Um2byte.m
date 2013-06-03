% Um2Byte.m - Convert raw Um data to bytes, Um_bit_seq should be 184 bits
% long (4 NB raw data).
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

function MS_byte_seq = Um2byte(Um_bit_seq)

MS_byte_seq = zeros(1,23);

le = length(Um_bit_seq);

if le ~= 184
    fprintf('NB size is not 184 bits');
else
    % change bit order
    MS_bit_seq = bit_order(Um_bit_seq,'rx');
    
    n_bit = 8; % bits per octet
    n_oct = 23; % complete octets
    
    for oct = 0:n_oct-1
        tmp = [];
        for bit = 1:n_bit
            tmp = [ tmp num2str(MS_bit_seq(oct*8+bit)) ];
        end
        MS_byte_seq(oct+1) = bin2dec(tmp);
    end
end
end