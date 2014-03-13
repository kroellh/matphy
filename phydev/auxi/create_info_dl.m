% create_info_dl.m - Create an L1CTL INFO_DL header
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

function info_dl = create_info_dl()

info_dl.chan_nr = 0;
info_dl.link_id = 0;
info_dl.band_arfcn = 0;
info_dl.frame_nr = 0;
info_dl.rx_level = 0;
info_dl.snr = 0;
info_dl.num_biterr = 0;
info_dl.fire_crc = 0;

end