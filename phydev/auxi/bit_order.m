% bit_order.m - Change the bit order. The rxtx paramter switches between
% from normal bit order to transmission bit order and the other way around.
% This procedure is described in 3GPP TS 44.004
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

function changed_bit_seq = bit_order(bit_seq,rxtx)

le = length(bit_seq);
changed_bit_seq = zeros(1,le);
n_bit = 8; % number of bits in octet
n_oct = floor(le/n_bit); % number of octets
r_bit = rem(le,n_bit);

switch rxtx
    case 'rx' % change from bit order on Um to bit order in mobile
        for oct = 0:n_oct-1
            for bit = 0:n_bit-1
                changed_bit_seq(oct*n_bit+bit+1) = bit_seq((oct+1)*n_bit-bit);
            end
        end
        if r_bit > 0
            for bit = 0:r_bit-1
                changed_bit_seq(n_oct*n_bit+bit+1) = bit_seq(n_oct*n_bit+r_bit-bit);
            end
        end
        
    case 'tx' % change from bit order in mobile to bit order in Um
        for oct = 0:n_oct-1
            for bit = 0:n_bit-1
                changed_bit_seq(oct*n_bit+bit+1) = bit_seq((oct+1)*n_bit-bit);
            end
        end
        if r_bit > 0
            for bit = 0:r_bit-1
                changed_bit_seq(n_oct*n_bit+bit+1) = bit_seq(n_oct*n_bit+r_bit-bit);
            end
        end
    otherwise
        fprintf('Invalid rxtx parameter\n');
end

end