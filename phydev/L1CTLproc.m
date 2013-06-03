% L1CTLproc.m - Switch for L1CTL messages from higher layers
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

switch phyconnect.getMsgTypeFromL2
    case phyconnect.FBSB_REQ
        fprintf('Receiving FBSB_REQ\n');
        FBSB_REQ_handle(phyconnect,dfe,det,dec,tpu);
    case phyconnect.PM_REQ
        fprintf('Receiving PM_REQ\n');
        PM_REQ_handle(phyconnect,dfe,tpu);
    case phyconnect.RESET_REQ
        fprintf('Receiving RESET_REQ\n');
        RESET_REQ_handle(phyconnect,tpu);
    case phyconnect.CCCH_MODE_REQ
        fprintf('Receiving CCCH_MODE_REQ\n');
        CCCH_MODE_REQ_handle(phyconnect,tpu);
    otherwise
        error('Receiving unknown message type\n');
end
% mark message as read
phyconnect.setAckToL2();