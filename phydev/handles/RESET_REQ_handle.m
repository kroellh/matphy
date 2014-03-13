% RESET_REQ_handle.m - process RESET_REQ
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

function RESET_REQ_handle(phyconnect,gsmphy,dfe,det,dec,tpu)

MatPhyConfig;

resetreq = phyconnect.getRESET_REQ;
% check type of reset request
switch resetreq.type
    case RES_T_FULL
        fprintf('reset type: RES_T_FULL\n');
    case RES_T_SCHED
        fprintf('reset type: RES_T_SCHED\n');
    otherwise
        error('invalid reset request\n');
end

fprintf('performing reset\n');
tpu.reset;
phyconnect.setPhyFsmState(S_NULL);
% TODO: type
% TODO: clear memories in dfe, det, dec

phyconnect.putRESET_CONF(resetreq.type);

end
